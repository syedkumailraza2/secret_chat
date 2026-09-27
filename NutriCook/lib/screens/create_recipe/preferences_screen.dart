import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/user_preferences.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_header.dart';
import 'generating_screen.dart';
import 'results_screen.dart';

/// create-preference.html — goal, meal, cooking time and servings.
class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key});

  static const _goals = <(String, String, IconData)>[
    ('high_protein', 'High Protein', Symbols.fitness_center),
    ('low_calorie', 'Low Calorie', Symbols.scale),
    ('balanced', 'Balanced', Symbols.balance),
    ('weight_loss', 'Weight Loss', Symbols.trending_down),
    // The design uses a QR-code glyph here, which reads as a slip; the
    // equivalent fitness glyph is used instead.
    ('muscle_gain', 'Muscle Gain', Symbols.exercise),
  ];

  static const _meals = <(String, String)>[
    ('breakfast', 'Breakfast'),
    ('lunch', 'Lunch'),
    ('dinner', 'Dinner'),
    ('snack', 'Snack'),
  ];

  Future<void> _generate(BuildContext context) async {
    final recipeProvider = context.read<RecipeProvider>();
    final user = context.read<UserProvider>();
    final navigator = Navigator.of(context);

    // Generation runs behind the full-screen progress route, which pops with
    // `true` once recipes are ready.
    unawaited(
      recipeProvider.generateRecipes(
        diet: user.preferences.diet?.apiValue,
        allergies: user.effectiveAllergies,
        cuisines: user.effectiveCuisines,
      ),
    );

    final succeeded = await Navigator.of(context, rootNavigator: true)
        .push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const GeneratingScreen(),
      ),
    );

    if (succeeded == true) {
      navigator.push(
        MaterialPageRoute(builder: (_) => const ResultsScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipes = context.watch<RecipeProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppTopBar(),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.margin,
          AppSpacing.lg,
          AppSpacing.margin,
          BottomNavBar.reservedSpace(context) + AppSpacing.lg,
        ),
        children: [
          Text(
            'What are you looking for?',
            style: AppTextStyles.displayLg.copyWith(
              color: AppColors.onPrimaryFixedVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Customize your AI-generated meal plan',
            style: AppTextStyles.body.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // --- Goal ---
          const SectionHeader(title: 'Goal', icon: Symbols.target),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 520 ? 3 : 2;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 1.35,
                children: [
                  for (final (value, label, icon) in _goals)
                    _GoalTile(
                      label: label,
                      icon: icon,
                      selected: recipes.goal == value,
                      onTap: () =>
                          context.read<RecipeProvider>().setGoal(value),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          // --- Meal ---
          const SectionHeader(title: 'Meal', icon: Symbols.restaurant),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _meals.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) {
                final (value, label) = _meals[i];
                return CategoryChip(
                  label: label,
                  selected: recipes.meal == value,
                  selectedColor: AppColors.primaryContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  onTap: () => context.read<RecipeProvider>().setMeal(value),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // --- Cooking time ---
          const SectionHeader(title: 'Cooking Time', icon: Symbols.timer),
          const SizedBox(height: AppSpacing.md),
          for (final band in CookingTimeBand.values) ...[
            _TimeOption(
              label: band.label,
              selected: recipes.timeBand == band,
              onTap: () => context.read<RecipeProvider>().setTimeBand(band),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.lg),

          // --- Servings ---
          const SectionHeader(title: 'Servings', icon: Symbols.group),
          const SizedBox(height: AppSpacing.md),
          _ServingsStepper(
            value: recipes.servings,
            onChanged: (v) => context.read<RecipeProvider>().setServings(v),
          ),
          const SizedBox(height: AppSpacing.xl),

          const Divider(color: AppColors.surfaceVariant),
          const SizedBox(height: AppSpacing.lg),

          PrimaryButton(
            label: 'Generate Healthy Recipes  ✨',
            icon: null,
            pill: true,
            glow: true,
            onPressed: () => _generate(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'AI will create a custom recipe based on your preferences',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GoalTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryContainer.withValues(alpha: 0.05)
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.normal),
          border: Border.all(
            color: selected
                ? AppColors.primaryContainer
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: selected
                  ? AppColors.primaryContainer
                  : AppColors.outline,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.small.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TimeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.normal),
          border: Border.all(
            color: selected
                ? AppColors.primaryContainer
                : AppColors.surfaceVariant,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.small),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? AppColors.primaryContainer
                      : AppColors.outlineVariant,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ServingsStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _ServingsStepper({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.normal),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stepButton(
            Symbols.remove,
            onTap: value > 1 ? () => onChanged(value - 1) : null,
          ),
          Column(
            children: [
              Text('$value', style: AppTextStyles.displayLg),
              Text(
                'People',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          _stepButton(
            Symbols.add,
            highlighted: true,
            onTap: value < 12 ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }

  Widget _stepButton(
    IconData icon, {
    VoidCallback? onTap,
    bool highlighted = false,
  }) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: highlighted
                ? AppColors.primaryContainer.withValues(alpha: 0.1)
                : AppColors.surfaceContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: highlighted
                ? AppColors.primaryContainer
                : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
