import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';

/// Full-width pill "Log today +" call to action with its caption.
class LogButton extends StatefulWidget {
  const LogButton({
    super.key,
    required this.onPressed,
    this.label = 'Log today',
    this.caption = '30 seconds to keep your history accurate.',
  });

  final VoidCallback onPressed;
  final String label;
  final String caption;

  @override
  State<LogButton> createState() => _LogButtonState();
}

class _LogButtonState extends State<LogButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: widget.label,
          excludeSemantics: true,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.onPressed,
            child: AnimatedOpacity(
              opacity: _pressed ? 0.9 : 1,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                decoration: BoxDecoration(
                  color: c.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.label,
                      style: AppText.labelLg.copyWith(color: c.surface, letterSpacing: 0.025 * 14),
                    ),
                    const SizedBox(width: 8),
                    Icon(Symbols.add, size: 18, weight: 200, color: c.surface),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          widget.caption,
          textAlign: TextAlign.center,
          style: AppText.bodySm.copyWith(color: c.outline),
        ),
      ],
    );
  }
}
