import 'package:socket_io_client/socket_io_client.dart' as io;

/// Minimal seam over a Socket.IO socket so tests can inject a fake.
abstract class ChatSocket {
  void on(String event, void Function(dynamic data) handler);
  void emit(String event, [dynamic data]);
  void connect();
  void dispose();
}

typedef ChatSocketFactory =
    ChatSocket Function(String baseUrl, Map<String, dynamic> auth);

/// Real implementation backed by socket_io_client 3.x.
class SocketIoChatSocket implements ChatSocket {
  SocketIoChatSocket(String baseUrl, Map<String, dynamic> auth)
    : _socket = io.io(
        baseUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth(auth)
            .disableAutoConnect()
            // Never reuse a cached Manager: a nickname change must open a
            // fresh connection carrying the new auth payload.
            .enableForceNew()
            .build(),
      );

  final io.Socket _socket;

  static ChatSocket create(String baseUrl, Map<String, dynamic> auth) =>
      SocketIoChatSocket(baseUrl, auth);

  @override
  void on(String event, void Function(dynamic data) handler) =>
      _socket.on(event, handler);

  @override
  void emit(String event, [dynamic data]) => _socket.emit(event, data);

  @override
  void connect() => _socket.connect();

  @override
  void dispose() {
    _socket.dispose();
    // Close the underlying engine too (forceNew => this Manager is ours).
    _socket.io.close();
  }
}
