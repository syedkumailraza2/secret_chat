/// Hidden single-room chat shared by Luna and NutriCook.
library;

import 'package:flutter/material.dart';

import 'src/dialogs.dart';
import 'src/client_id_store.dart';
import 'src/nickname_store.dart';
import 'src/secret_chat_api.dart';
import 'src/secret_chat_screen.dart';

bool _flowActive = false;

/// Runs the whole flow: code dialog → unlock → nickname (first time) →
/// chat screen. A wrong code closes the dialog silently.
///
/// Repeated calls while a flow (or the chat screen) is open are ignored.
Future<void> openSecretChat(
  BuildContext context, {
  required String baseUrl,
}) async {
  if (_flowActive) return;
  _flowActive = true;
  try {
    final code = await SecretCodeDialog.show(context);
    if (code == null || code.isEmpty || !context.mounted) return;

    final token = await unlockSecretChat(baseUrl, code);
    if (token == null || !context.mounted) return;

    final clientId = await ClientIdStore.load();
    var nickname = await NicknameStore.load();
    if (!context.mounted) return;
    if (nickname == null) {
      nickname = await NicknameDialog.show(context);
      if (nickname == null || nickname.isEmpty || !context.mounted) return;
      await NicknameStore.save(nickname);
      if (!context.mounted) return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SecretChatScreen(
          baseUrl: baseUrl,
          token: token,
          nickname: nickname!,
          clientId: clientId,
        ),
      ),
    );
  } finally {
    _flowActive = false;
  }
}
