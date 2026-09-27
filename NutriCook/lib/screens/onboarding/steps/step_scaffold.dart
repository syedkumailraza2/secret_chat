import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_text_styles.dart';

/// Shared layout for the four selection steps: heading, scrollable body, and a
/// footer CTA that stays reachable on short screens.
class StepScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget footer;

  /// The diet and cuisine steps centre their heading.
  final bool centerTitle;

  /// Optional full-bleed background (the diet step sits over photography).
  final Widget? background;

  const StepScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    required this.footer,
    this.centerTitle = false,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.margin,
              AppSpacing.md,
              AppSpacing.margin,
              AppSpacing.lg,
            ),
            children: [
              Text(
                title,
                textAlign: centerTitle ? TextAlign.center : TextAlign.start,
                style: AppTextStyles.displayLg,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle,
                textAlign: centerTitle ? TextAlign.center : TextAlign.start,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              ...children,
            ],
          ),
        ),
        // The CTA sits on a gradient that fades into the background, matching
        // the sticky footers in the HTML.
        Container(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.margin,
            AppSpacing.md,
            AppSpacing.margin,
            AppSpacing.md + MediaQuery.paddingOf(context).bottom,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                AppColors.background,
                AppColors.background,
                AppColors.background.withValues(alpha: 0),
              ],
            ),
          ),
          child: footer,
        ),
      ],
    );

    if (background == null) return content;

    return Stack(
      fit: StackFit.expand,
      children: [background!, content],
    );
  }
}
