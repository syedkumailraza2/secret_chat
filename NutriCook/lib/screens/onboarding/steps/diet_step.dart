import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../models/user_preferences.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/recipe_image.dart';
import '../../../widgets/selection_card.dart';
import '../onboarding_images.dart';
import 'step_scaffold.dart';

/// onboarding3.html — single-select diet over a soft photographic background.
class DietStep extends StatelessWidget {
  final VoidCallback onContinue;

  const DietStep({super.key, required this.onContinue});

  static const _options = <(Diet, IconData, String)>[
    (Diet.vegetarian, Symbols.nutrition, 'No meat, includes dairy & eggs.'),
    (Diet.vegan, Symbols.spa, 'Strictly plant-based ingredients.'),
    (Diet.nonVegetarian, Symbols.restaurant, 'Includes all meats and poultry.'),
    (Diet.pescatarian, Symbols.set_meal, 'Includes seafood, dairy & eggs.'),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = context.watch<UserProvider>().preferences.diet;

    return StepScaffold(
      title: 'What’s your diet?',
      subtitle: 'Select your primary dietary preference to help us curate the '
          'perfect recipes.',
      centerTitle: true,
      background: const _DietBackground(),
      footer: PrimaryButton(
        label: 'Continue',
        pill: true,
        onPressed: selected == null ? null : onContinue,
      ),
      children: [
        for (final (diet, icon, subtitle) in _options) ...[
          SelectionCard(
            icon: icon,
            title: diet.label,
            subtitle: subtitle,
            selected: selected == diet,
            onTap: () => context.read<UserProvider>().setDiet(diet),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _DietBackground extends StatelessWidget {
  const _DietBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // The design runs the photograph at 40% opacity behind everything.
        Opacity(
          opacity: 0.4,
          child: const RecipeImage(url: OnboardingImages.dietBg),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.background.withValues(alpha: 0.8),
                AppColors.background.withValues(alpha: 0.6),
                AppColors.background.withValues(alpha: 0.95),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
