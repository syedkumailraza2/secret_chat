import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/recipe_image.dart';
import '../onboarding/onboarding_images.dart';

/// onboarding1.html — the hero welcome, now the front door.
///
/// The design's single "Get Started" CTA becomes two: creating an account and
/// signing back into one. The hero treatment is unchanged.
class AuthWelcomeScreen extends StatelessWidget {
  const AuthWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // The design gives the photograph the top half and the copy the
          // rest; a little less here, because there are now two CTAs.
          final imageHeight = constraints.maxHeight * 0.52;

          return Stack(
            children: [
              SizedBox(
                height: imageHeight,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(AppRadius.xl),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const RecipeImage(url: OnboardingImages.welcome),
                      // Fades the photo into the page background so the copy
                      // below reads cleanly.
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              AppColors.background,
                              AppColors.background.withValues(alpha: 0.4),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.margin,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          const Icon(
                            Symbols.eco,
                            size: 28,
                            fill: 1,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'NutriCook',
                            style: AppTextStyles.h1
                                .copyWith(color: AppColors.primary),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Eat better.\n'),
                            TextSpan(
                              text: 'Cook smarter.',
                              style: TextStyle(color: AppColors.primary),
                            ),
                          ],
                        ),
                        style: AppTextStyles.displayLg,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Create healthy recipes from the ingredients you '
                        'already have. Your personal AI sous-chef awaits.',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      PrimaryButton(
                        label: 'Get Started',
                        onPressed: () =>
                            Navigator.of(context).pushNamed(AppRoutes.signUp),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Center(
                        child: TextButton(
                          onPressed: () =>
                              Navigator.of(context).pushNamed(AppRoutes.logIn),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Already have an account? ',
                                  style: AppTextStyles.small.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                                TextSpan(
                                  text: 'Log in',
                                  style: AppTextStyles.small.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
