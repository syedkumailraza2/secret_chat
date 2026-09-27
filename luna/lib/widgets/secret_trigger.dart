import 'package:flutter/widgets.dart';
import 'package:secret_chat_kit/secret_chat_kit.dart';

import '../utils/constants.dart';

/// Wraps [child] so a long-press opens the chat flow. Adds no tap handler
/// and no visual or semantic change.
class SecretTrigger extends StatelessWidget {
  const SecretTrigger({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onLongPress: () => openSecretChat(context, baseUrl: secretChatBaseUrl),
      child: child,
    );
  }
}
