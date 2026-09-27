import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nickname_store.dart';

/// A deliberately bland code prompt. It never mentions chat and never shows
/// an error; it just returns what was typed, or null when dismissed.
class SecretCodeDialog extends StatefulWidget {
  const SecretCodeDialog({super.key});

  static Future<String?> show(BuildContext context) => showDialog<String>(
    context: context,
    builder: (_) => const SecretCodeDialog(),
  );

  @override
  State<SecretCodeDialog> createState() => _SecretCodeDialogState();
}

class _SecretCodeDialogState extends State<SecretCodeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: TextField(
        key: const ValueKey('secret_code_field'),
        controller: _controller,
        autofocus: true,
        obscureText: true,
        enableSuggestions: false,
        autocorrect: false,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(isDense: true),
      ),
      actions: [TextButton(onPressed: _submit, child: const Text('OK'))],
    );
  }
}

/// Asks for a nickname (1–24 characters). Returns null when cancelled.
class NicknameDialog extends StatefulWidget {
  const NicknameDialog({super.key, this.initial});

  final String? initial;

  static Future<String?> show(BuildContext context, {String? initial}) =>
      showDialog<String>(
        context: context,
        builder: (_) => NicknameDialog(initial: initial),
      );

  @override
  State<NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends State<NicknameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial ?? '',
  );

  bool get _valid {
    final t = _controller.text.trim();
    return t.isNotEmpty && t.length <= NicknameStore.maxLength;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_valid) Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nickname'),
      content: TextField(
        key: const ValueKey('nickname_field'),
        controller: _controller,
        autofocus: true,
        maxLength: NicknameStore.maxLength,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _valid ? _submit : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
