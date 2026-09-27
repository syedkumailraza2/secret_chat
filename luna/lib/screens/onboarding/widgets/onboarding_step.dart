import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/text_styles.dart';

/// Shared layout for one onboarding step: header (Luna mark or back arrow +
/// "0N / 03"), a scrollable body, and a bottom pill CTA.
class OnboardingStep extends StatelessWidget {
  const OnboardingStep({
    super.key,
    required this.step,
    required this.child,
    required this.ctaLabel,
    required this.ctaTrailing,
    required this.onCta,
    this.total = 3,
    this.onBack,
    this.footnote,
    this.background,
  });

  final int step;
  final int total;

  /// When null the Luna wordmark is shown instead of a back arrow.
  final VoidCallback? onBack;
  final Widget child;
  final String ctaLabel;
  final Widget ctaTrailing;

  /// Null disables the CTA.
  final VoidCallback? onCta;
  final Widget? footnote;
  final Widget? background;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (background != null) Positioned.fill(child: background!),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 576), // max-w-xl
              child: Column(
                children: [
                  _Header(step: step, total: total, onBack: onBack),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) => SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.margin),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: c.maxHeight),
                          child: IntrinsicHeight(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: child),
                                Padding(
                                  padding: const EdgeInsets.only(top: AppSpacing.md, bottom: 16),
                                  child: Column(
                                    children: [
                                      PillButton(
                                        label: ctaLabel,
                                        trailing: ctaTrailing,
                                        onPressed: onCta,
                                      ),
                                      if (footnote != null) ...[
                                        const SizedBox(height: 16),
                                        footnote!,
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.step, required this.total, this.onBack});

  final int step;
  final int total;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = AppText.labelMd.copyWith(color: c.onSurfaceVariant, letterSpacing: 1.2);
    String two(int n) => n.toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.margin, 12, AppSpacing.margin, 8),
      child: SizedBox(
        height: 40,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (onBack == null)
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Luna',
                    style: AppText.headlineSm.copyWith(
                      color: c.primary,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -0.55,
                    ),
                  ),
                ],
              )
            else
              Transform.translate(
                offset: const Offset(-8, 0), // -ml-2
                child: IconButton(
                  onPressed: onBack,
                  tooltip: 'Go back',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  style: IconButton.styleFrom(overlayColor: Colors.transparent),
                  icon: Icon(Symbols.arrow_back, size: 24, weight: 200, color: c.onSurface),
                ),
              ),
            Text.rich(
              TextSpan(
                style: label,
                children: [
                  TextSpan(text: '${two(step)} '),
                  TextSpan(
                    text: '/',
                    style: label.copyWith(color: c.outlineVariant).weight(300),
                  ),
                  TextSpan(text: ' ${two(total)}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width 52px primary pill (bg-primary-container, text-surface).
class PillButton extends StatefulWidget {
  const PillButton({super.key, required this.label, required this.trailing, this.onPressed});

  final String label;
  final Widget trailing;
  final VoidCallback? onPressed;

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> {
  bool _down = false;

  void _setDown(bool v) {
    if (widget.onPressed != null && v != _down) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: (_) => _setDown(true),
        onTapUp: (_) => _setDown(false),
        onTapCancel: () => _setDown(false),
        onTap: widget.onPressed,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: enabled ? (_down ? 0.95 : 1) : 0.4,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 150),
            scale: _down ? 0.99 : 1,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: c.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: IconTheme.merge(
                data: IconThemeData(color: c.surface),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: c.surface),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(widget.label, style: AppText.labelLg.copyWith(color: c.surface)),
                      const SizedBox(width: 8),
                      widget.trailing,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
