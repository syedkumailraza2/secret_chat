import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_chat_kit/src/dialogs.dart';

void main() {
  Future<void> pumpHost(
    WidgetTester tester,
    Future<String?> Function(BuildContext) open,
    void Function(String?) onResult,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => onResult(await open(context)),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('code dialog returns the entered code on OK', (tester) async {
    String? result = 'unset';
    await pumpHost(tester, SecretCodeDialog.show, (r) => result = r);
    await tester.enterText(find.byType(TextField), ' 4321 ');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(result, '4321');
    expect(find.byType(SecretCodeDialog), findsNothing);
  });

  testWidgets('code dialog submits on Enter', (tester) async {
    String? result = 'unset';
    await pumpHost(tester, SecretCodeDialog.show, (r) => result = r);
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(result, 'abc');
  });

  testWidgets('code dialog returns null when dismissed', (tester) async {
    String? result = 'unset';
    await pumpHost(tester, SecretCodeDialog.show, (r) => result = r);
    await tester.tapAt(const Offset(5, 5)); // barrier
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.byType(SecretCodeDialog), findsNothing);
  });

  testWidgets('code dialog never mentions chat', (tester) async {
    await pumpHost(tester, SecretCodeDialog.show, (_) {});
    expect(
      find.textContaining(RegExp('chat', caseSensitive: false)),
      findsNothing,
    );
  });

  testWidgets('nickname dialog validates and cancels', (tester) async {
    String? result = 'unset';
    await pumpHost(tester, NicknameDialog.show, (r) => result = r);
    final save = find.widgetWithText(TextButton, 'Save');
    expect(tester.widget<TextButton>(save).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '  Amy ');
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(result, 'Amy');

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
