import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/recipe.dart';
import '../../providers/saved_provider.dart';
import '../../widgets/favorite_button.dart';
import '../../widgets/nutrition_card.dart';
import '../../widgets/recipe_image.dart';
import '../../widgets/recipe_meta.dart';

/// reciepe-details.html — hero image, rating, meta, nutrition, ingredients
/// and instructions.
class RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final saved = context.watch<SavedProvider>();
    final isSaved = saved.isSaved(recipe.id);
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              // Hero image — 45% of the viewport, floor of 350 as in the CSS.
              SizedBox(
                height: (MediaQuery.sizeOf(context).height * 0.45)
                    .clamp(350.0, 520.0),
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(AppRadius.xl),
                  ),
                  child: RecipeImage(url: recipe.imageUrl),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -AppSpacing.md),
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppRadius.xl),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.margin,
                    AppSpacing.lg,
                    AppSpacing.margin,
                    AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (recipe.rating > 0) ...[
                        Row(
                          children: [
                            const Icon(
                              Symbols.star,
                              size: 22,
                              fill: 1,
                              color: AppColors.tertiaryFixedDim,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              recipe.rating.toStringAsFixed(1),
                              style: AppTextStyles.h3,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              '(${recipe.reviewCount} reviews)',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      Text(recipe.name, style: AppTextStyles.h1),
                      if (recipe.description.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          recipe.description,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      MetaRow(
                        cookingTime: recipe.cookingTime,
                        difficulty: recipe.difficulty,
                        servings: recipe.servings,
                        gradeDifficultyIcon: false,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      NutritionCard(nutrition: recipe.nutrition),
                      const SizedBox(height: AppSpacing.xl),

                      Text('Ingredients', style: AppTextStyles.h2),
                      const SizedBox(height: AppSpacing.md),
                      for (final ingredient in recipe.ingredients) ...[
                        _IngredientRow(
                          name: ingredient.name,
                          measurement: ingredient.measurement,
                          optional: ingredient.optional,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      const SizedBox(height: AppSpacing.lg),

                      Text('Instructions', style: AppTextStyles.h2),
                      const SizedBox(height: AppSpacing.md),
                      for (var i = 0;
                          i < recipe.instructions.length;
                          i++) ...[
                        _InstructionRow(
                          step: i + 1,
                          text: recipe.instructions[i],
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Floating back / save controls over the hero.
          Positioned(
            top: topInset + AppSpacing.sm,
            left: AppSpacing.margin,
            right: AppSpacing.margin,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CircleButton(
                  icon: Symbols.arrow_back,
                  onTap: () => Navigator.of(context).pop(),
                ),
                FavoriteButton(
                  isSaved: isSaved,
                  onTap: () =>
                      context.read<SavedProvider>().toggleSave(recipe),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          boxShadow: AppShadows.soft,
        ),
        child: Icon(icon, size: 20, color: AppColors.onSurface),
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  final String name;
  final String measurement;
  final bool optional;

  const _IngredientRow({
    required this.name,
    required this.measurement,
    required this.optional,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: name),
                  // The brief asks that optional ingredients be identifiable.
                  if (optional)
                    TextSpan(
                      text: '  (optional)',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              style: AppTextStyles.body,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            measurement,
            style: AppTextStyles.small.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionRow extends StatelessWidget {
  final int step;
  final String text;

  const _InstructionRow({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(top: 2),
          decoration: const BoxDecoration(
            color: AppColors.primaryContainer,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$step',
            style: AppTextStyles.h3.copyWith(
              color: AppColors.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.body.copyWith(height: 1.65),
          ),
        ),
      ],
    );
  }
}
