import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_text_styles.dart';
import 'primary_button.dart';

/// The friendly failure state. Never shows a status code or a raw exception —
/// the message it receives has already been translated by ApiService.
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  /// The lighter line under the headline.
  final String? hint;

  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Symbols.restaurant_menu,
                size: 34,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              AppMessages.genericError,
              textAlign: TextAlign.center,
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              hint ?? message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: 200,
                child: PrimaryButton(
                  label: AppMessages.tryAgain,
                  icon: Symbols.refresh,
                  pill: true,
                  onPressed: onRetry,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The empty state for a list with nothing in it yet.
class EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, textAlign: TextAlign.center, style: AppTextStyles.h2),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
