import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';

/// The chrome shared by the sign-up and sign-in screens: back button, the
/// NutriCook wordmark, a Playfair headline and a scrollable form body.
///
/// Matches the onboarding header so arriving at either screen feels like the
/// same flow rather than a different app.
class AuthFormScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const AuthFormScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.margin,
                AppSpacing.sm,
                AppSpacing.margin,
                0,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Symbols.arrow_back,
                        size: 20,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'NutriCook',
                      textAlign: TextAlign.center,
                      style:
                          AppTextStyles.h1.copyWith(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.margin,
                  AppSpacing.lg,
                  AppSpacing.margin,
                  MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
                ),
                children: [
                  Text(title, style: AppTextStyles.displayLg),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    subtitle,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ...children,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The inline failure banner above a form's CTA.
///
/// Errors belong next to the thing that failed, not in a snackbar that slides
/// away while the user is still reading it.
class AuthErrorBanner extends StatelessWidget {
  final String? message;

  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Symbols.error,
            size: 20,
            color: AppColors.onErrorContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message!,
              style: AppTextStyles.small.copyWith(
                color: AppColors.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
