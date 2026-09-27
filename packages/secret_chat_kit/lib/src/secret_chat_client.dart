import 'package:flutter/foundation.dart';

import 'chat_message.dart';
import 'chat_socket.dart';
import 'client_id_store.dart';

enum ChatStatus {
  connecting,
  connected,
  reconnecting,
  unauthorized,
  disconnected,
}

/// Holds the live state of the chat room and talks to the server.
class SecretChatClient extends ChangeNotifier {
  SecretChatClient({
    required this.baseUrl,
    required this.token,
    required String name,
    String? clientId,
    ChatSocketFactory? socketFactory,
  }) : _myName = name,
       clientId = clientId ?? ClientIdStore.generate(),
       _socketFactory = socketFactory ?? SocketIoChatSocket.create;

  static const maxMessageLength = 1000;

  final String baseUrl;
  final String token;

  /// Who this device is in the room. Stable across nickname changes.
  final String clientId;
  final ChatSocketFactory _socketFactory;

  String _myName;
  String get myName => _myName;

  final List<ChatMessage> _messages = [];
  final Set<String> _ids = {};
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  int _online = 0;
  int get online => _online;

  ChatStatus _status = ChatStatus.connecting;
  ChatStatus get status => _status;

  /// Transient server error messages (e.g. rate limits) for a snackbar.
  final ValueNotifier<String?> lastError = ValueNotifier(null);

  ChatSocket? _socket;
  bool _everConnected = false;
  bool _disposed = false;

  /// A rename made while offline, sent as soon as the socket is back so the
  /// server also relabels past messages.
  bool _renamePending = false;

  /// Opens the connection. Safe to call once after construction.
  void connect() {
    _openSocket();
  }

  /// Changes the nickname in place. Connected, the server renames this
  /// sender's messages for everyone and nobody sees a leave/join. Otherwise
  /// the new name goes out with the next (re)connection.
  void changeName(String name) {
    final n = name.trim();
    if (n.isEmpty || n == _myName || _disposed) return;
    _myName = n;
    _auth['name'] = n;
    _applyRename(clientId, n);
    if (_status == ChatStatus.connected && _socket != null) {
      _socket!.emit('rename', {'name': n});
    } else {
      _renamePending = true;
    }
    _notify();
  }

  /// Sends a message; returns false when nothing was sent.
  bool send(String text) {
    final t = text.trim();
    if (t.isEmpty || t.length > maxMessageLength) return false;
    if (_status != ChatStatus.connected || _socket == null) return false;
    _socket!.emit('send_message', {'text': t});
    return true;
  }

  /// Messages from before sender ids existed fall back to the nickname.
  bool isMine(ChatMessage m) =>
      m.senderId != null ? m.senderId == clientId : m.name == _myName;

  // Kept as one mutable map so the library's automatic reconnects send the
  // current nickname, not the one the socket was created with.
  late final Map<String, dynamic> _auth = {
    'token': token,
    'name': _myName,
    'client_id': clientId,
  };

  void _openSocket() {
    if (_disposed) return;
    final s = _socketFactory(baseUrl, _auth);
    _socket = s;
    s.on('connect', (_) {
      if (!identical(_socket, s)) return;
      _everConnected = true;
      if (_renamePending) {
        _renamePending = false;
        s.emit('rename', {'name': _myName});
      }
      _setStatus(ChatStatus.connected);
    });
    s.on('connect_error', (data) {
      if (!identical(_socket, s)) return;
      if (_isAuthRefusal(data)) {
        _setStatus(ChatStatus.unauthorized);
        // Dispose outside the socket's own event dispatch.
        Future.microtask(() {
          if (identical(_socket, s)) _closeSocket();
        });
        return;
      }
      // Transport-level failure: the manager keeps retrying.
      if (_everConnected) _setStatus(ChatStatus.reconnecting);
    });
    s.on('disconnect', (reason) {
      if (!identical(_socket, s)) return;
      if (_status == ChatStatus.unauthorized) return;
      if (reason == 'io client disconnect') {
        _setStatus(ChatStatus.disconnected);
        return;
      }
      _setStatus(ChatStatus.reconnecting);
      // The client library does not auto-reconnect after a server-side
      // disconnect; try once more (an expired token then yields
      // connect_error "unauthorized").
      if (reason == 'io server disconnect') s.connect();
    });
    s.on('history', (data) {
      if (!identical(_socket, s)) return;
      handleHistory(data);
    });
    s.on('message', (data) {
      if (!identical(_socket, s)) return;
      handleMessage(data);
    });
    s.on('renamed', (data) {
      if (!identical(_socket, s)) return;
      handleRenamed(data);
    });
    s.on('presence', (data) {
      if (!identical(_socket, s)) return;
      handlePresence(data);
    });
    s.on('error', (data) {
      if (!identical(_socket, s)) return;
      // socket_io_client also emits 'error' for its own transport failures;
      // only the server's {"message": ...} payloads are meant for the user.
      if (data is! Map) return;
      final msg = data['message']?.toString();
      if (msg != null && msg.isNotEmpty) {
        lastError.value = null;
        lastError.value = msg;
      }
    });
    s.connect();
  }

  static bool _isAuthRefusal(dynamic data) {
    final msg = data is Map ? data['message'] : data;
    return msg == 'unauthorized' ||
        msg == 'invalid_name' ||
        msg == 'invalid_client';
  }

  @visibleForTesting
  void handleHistory(dynamic data) {
    if (data is! List) return;
    _messages.clear();
    _ids.clear();
    for (final raw in data) {
      final m = ChatMessage.tryParse(raw);
      if (m != null && _ids.add(m.id)) _messages.add(m);
    }
    _notify();
  }

  @visibleForTesting
  void handleMessage(dynamic data) {
    final m = ChatMessage.tryParse(data);
    if (m == null || !_ids.add(m.id)) return;
    _messages.add(m);
    _notify();
  }

  @visibleForTesting
  void handleRenamed(dynamic data) {
    if (data is! Map) return;
    final id = data['sender_id'];
    final name = data['name'];
    if (id is! String || name is! String || name.isEmpty) return;
    if (_applyRename(id, name)) _notify();
  }

  /// Relabels every loaded message from [senderId]; true if any changed.
  bool _applyRename(String senderId, String name) {
    var changed = false;
    for (var i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      if (m.senderId == senderId && m.name != name) {
        _messages[i] = m.withName(name);
        changed = true;
      }
    }
    return changed;
  }

  @visibleForTesting
  void handlePresence(dynamic data) {
    final v = data is Map ? data['online'] : null;
    if (v is num && v.toInt() != _online) {
      _online = v.toInt();
      _notify();
    }
  }

  void _setStatus(ChatStatus s) {
    if (_status == s) return;
    _status = s;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _closeSocket() {
    final s = _socket;
    _socket = null;
    s?.dispose();
  }

  @override
  void dispose() {
    _disposed = true;
    _closeSocket();
    lastError.dispose();
    super.dispose();
  }
}
