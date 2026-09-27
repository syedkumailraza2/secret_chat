import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_text_styles.dart';

/// The filled CTA used on every screen.
///
/// The designs use two corner treatments — a 12px radius on the onboarding and
/// preference CTAs, and a full pill on the diet/allergy/detail screens — so
/// [pill] selects between them rather than each screen rolling its own button.
class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Places the icon before the label instead of after it (the "Start Cooking"
  /// play arrow sits on the left).
  final bool iconLeading;

  final bool pill;
  final bool isLoading;

  /// The pulsing shadow on create-preference.html's generate button.
  final bool glow;

  final Color background;
  final Color foreground;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon = Symbols.arrow_forward,
    this.iconLeading = false,
    this.pill = false,
    this.isLoading = false,
    this.glow = false,
    this.background = AppColors.primaryContainer,
    this.foreground = AppColors.onPrimary,
  });

  bool get _enabled => onPressed != null && !isLoading;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget._enabled;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.5,
      child: AnimatedScale(
        // active:scale-[0.98] in the HTML.
        scale: _pressed && enabled ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTap: enabled ? widget.onPressed : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: widget.background,
              borderRadius: BorderRadius.circular(
                widget.pill ? AppRadius.full : AppRadius.button,
              ),
              boxShadow: enabled
                  ? (widget.glow ? AppShadows.cta : AppShadows.active)
                  : null,
            ),
            child: _content(),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    if (widget.isLoading) {
      return SizedBox(
        height: 27,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: widget.foreground,
            ),
          ),
        ),
      );
    }

    final label = Flexible(
      child: Text(
        widget.label,
        style: AppTextStyles.h3.copyWith(color: widget.foreground),
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );

    final icon = widget.icon == null
        ? null
        : Icon(widget.icon, size: 20, color: widget.foreground);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null && widget.iconLeading) ...[
          icon,
          const SizedBox(width: AppSpacing.sm),
        ],
        label,
        if (icon != null && !widget.iconLeading) ...[
          const SizedBox(width: AppSpacing.sm),
          icon,
        ],
      ],
    );
  }
}
