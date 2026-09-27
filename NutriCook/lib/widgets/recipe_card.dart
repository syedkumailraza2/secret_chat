import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_text_styles.dart';
import '../models/recipe.dart';
import 'favorite_button.dart';
import 'recipe_image.dart';
import 'recipe_meta.dart';

/// The large "Recipe of the Day" card on home.html: full-bleed photo, dark
/// scrim, tag, serif title and three metadata pills.
class FeaturedRecipeCard extends StatelessWidget {
  final Recipe recipe;
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onToggleSave;

  const FeaturedRecipeCard({
    super.key,
    required this.recipe,
    required this.isSaved,
    required this.onTap,
    required this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          constraints: const BoxConstraints(minHeight: 300),
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: AppShadows.card,
          ),
          // The card sits in a scrolling list, so its height comes from the
          // caption block (floored at 300) rather than from the stack — an
          // expanding stack here would resolve to an infinite height.
          child: Stack(
            alignment: Alignment.bottomLeft,
            children: [
              Positioned.fill(child: RecipeImage(url: recipe.imageUrl)),
              // bg-black/20 in the design.
              Positioned.fill(
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.2)),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer
                            .withValues(alpha: 0.9),
                        borderRadius:
                            BorderRadius.circular(AppRadius.normal),
                      ),
                      child: Text(
                        'RECIPE OF THE DAY',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.onPrimaryContainer,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      recipe.name,
                      style: AppTextStyles.h1.copyWith(
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                            color: Color(0x66000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _pill('${recipe.calories} kcal'),
                        _pill('${recipe.protein.round()}g protein'),
                        _pill(
                          '${recipe.cookingTime} min',
                          icon: Symbols.schedule,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: AppSpacing.md,
                right: AppSpacing.md,
                child: FavoriteButton(
                  isSaved: isSaved,
                  onTap: onToggleSave,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.onSurface),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

/// The full-width result card from AI-result.html: 240px photo with badges,
/// then a serif title and the time/difficulty line.
class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final bool isSaved;
  final bool isImagePending;
  final VoidCallback onTap;
  final VoidCallback onToggleSave;

  const RecipeCard({
    super.key,
    required this.recipe,
    required this.isSaved,
    required this.onTap,
    required this.onToggleSave,
    this.isImagePending = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.normal),
          boxShadow: AppShadows.soft,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 240,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RecipeImage(
                    url: recipe.imageUrl,
                    isGenerating: isImagePending,
                  ),
                  Positioned(
                    top: AppSpacing.md,
                    right: AppSpacing.md,
                    child: FavoriteButton(
                      isSaved: isSaved,
                      onTap: onToggleSave,
                    ),
                  ),
                  Positioned(
                    bottom: AppSpacing.md,
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        NutritionBadge.calories(recipe.calories),
                        NutritionBadge(
                          icon: Symbols.fitness_center,
                          label: '${recipe.protein.round()}g Protein',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.name, style: AppTextStyles.h2),
                  const SizedBox(height: AppSpacing.sm),
                  MetaRow(
                    cookingTime: recipe.cookingTime,
                    difficulty: recipe.difficulty,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The two-column card from save-recipe.html.
class CompactRecipeCard extends StatelessWidget {
  final Recipe recipe;
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onToggleSave;

  const CompactRecipeCard({
    super.key,
    required this.recipe,
    required this.isSaved,
    required this.onTap,
    required this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.normal),
          border: Border.all(color: AppColors.surfaceContainer),
          boxShadow: AppShadows.soft,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The photo absorbs whatever height the caption leaves, so a long
            // title never pushes the card past its grid cell.
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RecipeImage(url: recipe.imageUrl),
                    Positioned(
                      top: AppSpacing.sm,
                      right: AppSpacing.sm,
                    child: FavoriteButton(
                      isSaved: isSaved,
                      onTap: onToggleSave,
                      size: 32,
                    ),
                  ),
                  if (recipe.aiGenerated)
                    Positioned(
                      bottom: AppSpacing.sm,
                      left: AppSpacing.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest
                              .withValues(alpha: 0.9),
                          borderRadius:
                              BorderRadius.circular(AppRadius.full),
                          border:
                              Border.all(color: AppColors.surfaceVariant),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Symbols.auto_awesome,
                              size: 12,
                              color: AppColors.tertiary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'AI Adapted',
                              style: AppTextStyles.caption
                                  .copyWith(fontSize: 10),
                            ),
                          ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Natural height: the caption takes what it needs and the photo
            // above flexes around it.
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    recipe.name,
                    style: AppTextStyles.h3.copyWith(height: 1.25),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _tag(
                        '${recipe.calories} kcal',
                        icon: Symbols.local_fire_department,
                      ),
                      _tag('${recipe.protein.round()}g P'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: AppColors.onSecondaryContainer),
            const SizedBox(width: 2),
          ],
          // Shrinkable so an unusually large figure ellipsizes instead of
          // overflowing a narrow card.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                color: AppColors.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
