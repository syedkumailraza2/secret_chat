import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat_message.dart';
import 'chat_socket.dart';
import 'dialogs.dart';
import 'nickname_store.dart';
import 'secret_chat_client.dart';

/// The chat room. Every color and text style comes from the host app's
/// [Theme], so it adopts whichever app it is embedded in.
class SecretChatScreen extends StatefulWidget {
  const SecretChatScreen({
    super.key,
    required this.baseUrl,
    required this.token,
    required this.nickname,
    this.clientId,
    this.socketFactory,
  });

  final String baseUrl;
  final String token;
  final String nickname;

  /// Stable device id; tests may omit it.
  final String? clientId;
  final ChatSocketFactory? socketFactory;

  @override
  State<SecretChatScreen> createState() => _SecretChatScreenState();
}

class _SecretChatScreenState extends State<SecretChatScreen> {
  late final SecretChatClient _client;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _client =
        SecretChatClient(
            baseUrl: widget.baseUrl,
            token: widget.token,
            name: widget.nickname,
            clientId: widget.clientId,
            socketFactory: widget.socketFactory,
          )
          ..addListener(_onClientChanged)
          ..connect();
    _client.lastError.addListener(_onError);
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _client.lastError.removeListener(_onError);
    _client.removeListener(_onClientChanged);
    _client.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onClientChanged() {
    if (_client.status == ChatStatus.unauthorized && !_closing) {
      _closing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
    if (mounted) setState(() {});
  }

  void _onError() {
    final msg = _client.lastError.value;
    if (msg == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
  }

  void _send() {
    if (_client.send(_input.text)) {
      _input.clear();
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    // The list is reversed, so offset 0 is the newest message.
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _changeNickname() async {
    final name = await NicknameDialog.show(context, initial: _client.myName);
    if (name == null || name.isEmpty || name == _client.myName) return;
    await NicknameStore.save(name);
    if (!mounted) return;
    _client.changeName(name);
  }

  String _subtitle() {
    switch (_client.status) {
      case ChatStatus.connected:
        return '${_client.online} online';
      case ChatStatus.reconnecting:
        return 'Reconnecting…';
      case ChatStatus.disconnected:
      case ChatStatus.unauthorized:
        return 'Offline';
      case ChatStatus.connecting:
        return 'Connecting…';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final messages = _client.messages;
    final canSend =
        _client.status == ChatStatus.connected && _input.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Chat'),
            Text(
              _subtitle(),
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'nick') _changeNickname();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'nick', child: Text('Change nickname')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_client.status == ChatStatus.reconnecting)
            _Banner(scheme: scheme, text: text),
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      _client.status == ChatStatus.connected
                          ? 'No messages yet'
                          : '',
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final idx = messages.length - 1 - i;
                      final m = messages[idx];
                      final prev = idx > 0 ? messages[idx - 1] : null;
                      final newDay =
                          prev == null || !_sameDay(prev.sentAt, m.sentAt);
                      final sameSender = !newDay && prev.name == m.name;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (newDay) _DaySeparator(date: m.sentAt),
                          _Bubble(
                            message: m,
                            mine: _client.isMine(m),
                            showName: !sameSender,
                          ),
                        ],
                      );
                    },
                  ),
          ),
          _InputBar(controller: _input, canSend: canSend, onSend: _send),
        ],
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) {
  final x = a.toLocal(), y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

class _Banner extends StatelessWidget {
  const _Banner({required this.scheme, required this.text});

  final ColorScheme scheme;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Reconnecting…',
              style: text.labelMedium?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;
    final label = diff == 0
        ? 'Today'
        : diff == 1
        ? 'Yesterday'
        : MaterialLocalizations.of(context).formatMediumDate(local);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.showName,
  });

  final ChatMessage message;
  final bool mine;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final bg = mine ? scheme.primary : scheme.surfaceContainerHigh;
    final fg = mine ? scheme.onPrimary : scheme.onSurface;
    final local = message.sentAt.toLocal();
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    const r = Radius.circular(18);
    const tail = Radius.circular(4);

    return Padding(
      padding: EdgeInsets.only(top: showName ? 8 : 2),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!mine && showName)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 2),
              child: Text(
                message.name,
                style: text.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.only(
                  topLeft: r,
                  topRight: r,
                  bottomLeft: mine ? r : tail,
                  bottomRight: mine ? tail : r,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                child: SelectableText(
                  message.text,
                  style: text.bodyMedium?.copyWith(color: fg),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(
              time,
              style: text.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: (text.labelSmall?.fontSize ?? 11) - 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.canSend,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool canSend;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('secret_chat_input'),
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: SecretChatClient.maxMessageLength,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Message',
                    counterText: '',
                    isDense: true,
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: scheme.primary),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Send',
                onPressed: canSend ? onSend : null,
                color: scheme.primary,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
