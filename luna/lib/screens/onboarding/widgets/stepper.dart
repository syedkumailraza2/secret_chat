import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/text_styles.dart';

/// One baseline adjuster: title + caption, large "N days" with − / + buttons,
/// and a typical-range helper, closed by a hairline.
class BaselineStepper extends StatelessWidget {
  const BaselineStepper({
    super.key,
    required this.title,
    required this.caption,
    required this.helper,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.semanticName,
  });

  final String title;
  final String caption;
  final String helper;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String semanticName;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.only(bottom: 32),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.outlineVariant.withValues(alpha: 0.4))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppText.headlineSm.copyWith(color: c.onSurface).weight(400),
                ),
              ),
              Text(
                caption.toUpperCase(),
                style: AppText.labelSm.copyWith(color: c.onSurfaceVariant, letterSpacing: 0.55),
              ),
            ],
          ),
          const SizedBox(height: 6 + 12),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$value',
                        style: AppText.displayHeroMobile.copyWith(
                          color: c.primary,
                          letterSpacing: -2.8,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'days',
                        style: AppText.headlineSm
                            .copyWith(color: c.onSurfaceVariant, fontStyle: FontStyle.italic)
                            .weight(400),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _RoundButton(
                icon: Symbols.remove,
                label: 'Decrease $semanticName',
                onTap: value > min ? () => onChanged(value - 1) : null,
              ),
              const SizedBox(width: 12),
              _RoundButton(
                icon: Symbols.add,
                label: 'Increase $semanticName',
                onTap: value < max ? () => onChanged(value + 1) : null,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            helper,
            style: AppText.bodySm.copyWith(color: c.onSurfaceVariant.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatefulWidget {
  const _RoundButton({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  State<_RoundButton> createState() => _RoundButtonState();
}

class _RoundButtonState extends State<_RoundButton> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap != null && v != _down) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = _down && widget.onTap != null;
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 150),
          scale: active ? 0.95 : 1,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: widget.onTap == null ? 0.4 : 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.surface.withValues(alpha: 0.5),
                border: Border.all(
                  color: active ? c.primary : c.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Icon(
                widget.icon,
                size: 18,
                weight: 200,
                color: active ? c.primary : c.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
