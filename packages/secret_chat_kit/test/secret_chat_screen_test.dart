import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_chat_kit/src/chat_socket.dart';
import 'package:secret_chat_kit/src/secret_chat_screen.dart';

class _Fake implements ChatSocket {
  final handlers = <String, void Function(dynamic)>{};
  final emitted = <(String, dynamic)>[];
  void fire(String e, [dynamic d]) => handlers[e]?.call(d);
  @override
  void on(String event, void Function(dynamic) handler) =>
      handlers[event] = handler;
  @override
  void emit(String event, [dynamic data]) => emitted.add((event, data));
  @override
  void connect() {}
  @override
  void dispose() {}
}

void main() {
  testWidgets('renders messages, sends, and pops on unauthorized', (
    tester,
  ) async {
    final fake = _Fake();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorSchemeSeed: Colors.green),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SecretChatScreen(
                  baseUrl: 'http://x',
                  token: 't',
                  nickname: 'amy',
                  socketFactory: (_, _) => fake,
                ),
              ),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Connecting…'), findsOneWidget);

    fake.fire('connect');
    fake.fire('presence', {'online': 2});
    fake.fire('history', [
      {
        'id': '1',
        'name': 'bo',
        'text': 'hello',
        'sent_at': '2026-09-23T10:00:00Z',
      },
      {
        'id': '2',
        'name': 'amy',
        'text': 'hey',
        'sent_at': '2026-09-23T10:01:00Z',
      },
    ]);
    await tester.pump();
    expect(find.text('2 online'), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
    expect(find.text('bo'), findsOneWidget); // name label for others
    expect(find.text('hey'), findsOneWidget);

    await tester.enterText(find.byType(TextField), ' yo ');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    expect(fake.emitted.last.$1, 'send_message');
    expect(fake.emitted.last.$2, {'text': 'yo'});

    fake.fire('connect_error', {'message': 'unauthorized'});
    await tester.pumpAndSettle();
    expect(find.byType(SecretChatScreen), findsNothing);
    expect(find.text('go'), findsOneWidget);
  });
}
