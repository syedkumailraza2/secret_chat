import 'package:flutter_test/flutter_test.dart';
import 'package:secret_chat_kit/src/chat_message.dart';
import 'package:secret_chat_kit/src/chat_socket.dart';
import 'package:secret_chat_kit/src/secret_chat_client.dart';

class FakeSocket implements ChatSocket {
  FakeSocket(this.auth);

  final Map<String, dynamic> auth;
  final Map<String, void Function(dynamic)> handlers = {};
  final List<(String, dynamic)> emitted = [];
  int connectCalls = 0;
  bool disposed = false;

  void fire(String event, [dynamic data]) => handlers[event]?.call(data);

  @override
  void on(String event, void Function(dynamic data) handler) =>
      handlers[event] = handler;

  @override
  void emit(String event, [dynamic data]) => emitted.add((event, data));

  @override
  void connect() => connectCalls++;

  @override
  void dispose() => disposed = true;
}

Map<String, dynamic> msg(
  String id,
  String name,
  String text, [
  String sentAt = '2026-09-23T10:15:00Z',
]) => {'id': id, 'name': name, 'text': text, 'sent_at': sentAt};

Map<String, dynamic> msgFrom(
  String id,
  String sender,
  String name,
  String text,
) => {...msg(id, name, text), 'sender_id': sender};

const me = 'device-amy-0001';

void main() {
  late List<FakeSocket> sockets;
  late SecretChatClient client;

  setUp(() {
    sockets = [];
    client = SecretChatClient(
      baseUrl: 'http://x',
      token: 'tok',
      name: 'amy',
      clientId: me,
      socketFactory: (url, auth) {
        final s = FakeSocket(auth);
        sockets.add(s);
        return s;
      },
    )..connect();
  });

  tearDown(() => client.dispose());

  test('connects with token and name in auth', () {
    expect(sockets.last.auth, {'token': 'tok', 'name': 'amy', 'client_id': me});
    expect(sockets.last.connectCalls, 1);
    expect(client.status, ChatStatus.connecting);
    sockets.last.fire('connect');
    expect(client.status, ChatStatus.connected);
  });

  test('parses messages as UTC and skips malformed ones', () {
    final m = ChatMessage.tryParse(msg('1', 'bo', 'hi'))!;
    expect(m.id, '1');
    expect(m.sentAt.isUtc, isTrue);
    expect(m.sentAt, DateTime.utc(2026, 9, 23, 10, 15));
    expect(ChatMessage.tryParse({'id': '2'}), isNull);
    expect(ChatMessage.tryParse('nope'), isNull);
  });

  test('history replaces the list, keeping server (oldest-first) order', () {
    sockets.last.fire('history', [msg('1', 'bo', 'a'), msg('2', 'amy', 'b')]);
    expect(client.messages.map((m) => m.id), ['1', '2']);

    // A reconnect resends history: it replaces, not appends.
    sockets.last.fire('history', [
      msg('1', 'bo', 'a'),
      msg('2', 'amy', 'b'),
      msg('3', 'bo', 'c'),
      {'garbage': true},
    ]);
    expect(client.messages.map((m) => m.id), ['1', '2', '3']);
  });

  test('message appends and dedupes by id', () {
    sockets.last.fire('history', [msg('1', 'bo', 'a')]);
    sockets.last.fire('message', msg('2', 'bo', 'b'));
    sockets.last.fire('message', msg('2', 'bo', 'b'));
    sockets.last.fire('message', msg('1', 'bo', 'a'));
    expect(client.messages.map((m) => m.id), ['1', '2']);
  });

  test('presence updates online count', () {
    sockets.last.fire('presence', {'online': 3});
    expect(client.online, 3);
  });

  test('send trims, rejects empty/oversized, only when connected', () {
    expect(client.send('hello'), isFalse); // not connected yet
    sockets.last.fire('connect');
    expect(client.send('   '), isFalse);
    expect(client.send('x' * 1001), isFalse);
    expect(client.send('  hi there  '), isTrue);
    expect(sockets.last.emitted, hasLength(1));
    expect(sockets.last.emitted.single.$1, 'send_message');
    expect(sockets.last.emitted.single.$2, {'text': 'hi there'});
  });

  test('auth refusal sets unauthorized; transport error does not', () async {
    sockets.last.fire('connect_error', 'websocket error');
    expect(client.status, ChatStatus.connecting);
    sockets.last.fire('connect_error', {'message': 'unauthorized'});
    expect(client.status, ChatStatus.unauthorized);
    await Future<void>.delayed(Duration.zero);
    expect(sockets.last.disposed, isTrue);
  });

  test('disconnect after connect -> reconnecting, then connected again', () {
    sockets.last.fire('connect');
    sockets.last.fire('disconnect', 'transport close');
    expect(client.status, ChatStatus.reconnecting);
    sockets.last.fire('connect');
    expect(client.status, ChatStatus.connected);
  });

  test('server disconnect triggers one manual reconnect', () {
    sockets.last.fire('connect');
    sockets.last.fire('disconnect', 'io server disconnect');
    expect(client.status, ChatStatus.reconnecting);
    expect(sockets.last.connectCalls, 2);
  });

  test('error event surfaces on lastError', () {
    String? seen;
    client.lastError.addListener(() => seen ??= client.lastError.value);
    sockets.last.fire('error', {'message': 'slow down'});
    expect(client.lastError.value, 'slow down');
    expect(seen, 'slow down');
  });

  test('changeName renames in place without reconnecting', () {
    final socket = sockets.last..fire('connect');
    socket.fire('history', [
      msgFrom('1', me, 'amy', 'mine'),
      msgFrom('2', 'device-bo-0002', 'bo', 'theirs'),
    ]);

    client.changeName('  zed ');

    expect(sockets.length, 1, reason: 'same socket, no leave/join');
    expect(socket.disposed, isFalse);
    expect(client.status, ChatStatus.connected);
    expect(socket.emitted.last.$1, 'rename');
    expect(socket.emitted.last.$2, {'name': 'zed'});
    expect(client.myName, 'zed');
    expect(client.messages.map((m) => m.name), ['zed', 'bo']);
    // Reconnects made by the library carry the new name.
    expect(socket.auth['name'], 'zed');
  });

  test('renamed relabels that sender everywhere', () {
    sockets.last
      ..fire('connect')
      ..fire('history', [
        msgFrom('1', 'device-bo-0002', 'bo', 'a'),
        msgFrom('2', me, 'amy', 'b'),
        msgFrom('3', 'device-bo-0002', 'bo', 'c'),
      ])
      ..fire('renamed', {'sender_id': 'device-bo-0002', 'name': 'Bobby'});
    expect(client.messages.map((m) => m.name), ['Bobby', 'amy', 'Bobby']);
  });

  test('isMine follows the device id, not the nickname', () {
    final same = ChatMessage.tryParse(
      msgFrom('1', 'device-other-9', 'amy', 'x'),
    )!;
    final renamed = ChatMessage.tryParse(msgFrom('2', me, 'old name', 'y'))!;
    final legacy = ChatMessage.tryParse(msg('3', 'amy', 'z'))!;
    expect(client.isMine(same), isFalse);
    expect(client.isMine(renamed), isTrue);
    expect(
      client.isMine(legacy),
      isTrue,
      reason: 'no sender id: name fallback',
    );
  });

  test('a rename made offline is sent once connected', () {
    client.changeName('zed');
    expect(sockets.last.emitted.where((e) => e.$1 == 'rename'), isEmpty);
    sockets.last.fire('connect');
    expect(sockets.last.emitted.last.$1, 'rename');
    expect(sockets.last.emitted.last.$2, {'name': 'zed'});
  });
}
