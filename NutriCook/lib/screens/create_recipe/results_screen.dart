import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/saved_provider.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/error_view.dart';
import '../../widgets/recipe_card.dart';
import 'generating_screen.dart';

/// AI-result.html — "Made for you ✨".
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  /// Runs a fresh generation behind the same progress screen the create flow
  /// uses, then returns here — the provider has swapped the recipes underneath
  /// and dropped the cached flag, so this screen simply rebuilds without the
  /// banner.
  Future<void> _regenerate(BuildContext context) async {
    final recipes = context.read<RecipeProvider>();

    unawaited(recipes.regenerate());

    await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const GeneratingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipes = context.watch<RecipeProvider>();
    final saved = context.watch<SavedProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: recipes.generatedRecipes.isEmpty
            ? ErrorView(
                message: recipes.error ?? 'No recipes yet.',
                onRetry: () => Navigator.of(context).pop(),
              )
            : ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.margin,
                  AppSpacing.lg,
                  AppSpacing.margin,
                  BottomNavBar.reservedSpace(context) + AppSpacing.lg,
                ),
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Symbols.temp_preferences_custom,
                        size: 32,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          'Made for you ✨',
                          style: AppTextStyles.displayLg,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    recipes.isCached
                        ? 'Someone else cooked these up from the same '
                            'ingredients.'
                        : 'Based on your ingredients and preferences.',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (recipes.isCached) ...[
                    _CachedBanner(
                      count: recipes.generatedRecipes.length,
                      onRegenerate: () => _regenerate(context),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  for (final recipe in recipes.generatedRecipes) ...[
                    RecipeCard(
                      recipe: recipe,
                      isSaved: saved.isSaved(recipe.id),
                      isImagePending: recipes.isImagePending(recipe.id),
                      onTap: () => AppRoutes.openRecipe(context, recipe),
                      onToggleSave: () =>
                          context.read<SavedProvider>().toggleSave(recipe),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Shown when the recipes came from the cache rather than from the model.
///
/// Says so plainly, and offers the way out — generating fresh ones — rather
/// than quietly passing somebody else's results off as new.
class _CachedBanner extends StatelessWidget {
  final int count;
  final Future<void> Function() onRegenerate;

  const _CachedBanner({required this.count, required this.onRegenerate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.nutritionBadge,
        borderRadius: BorderRadius.circular(AppRadius.normal),
        border: Border.all(color: AppColors.primaryFixedDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Symbols.recycling,
                size: 22,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Already cooked up',
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.onPrimaryFixed,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      count == 1
                          ? 'This recipe was made from these exact '
                              'ingredients before, so we saved you the wait.'
                          : 'These $count recipes were made from these exact '
                              'ingredients before, so we saved you the wait.',
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          GestureDetector(
            onTap: onRegenerate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(color: AppColors.primaryContainer),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Flexible, so a large text scale shortens the label
                  // rather than overflowing the pill it sits in.
                  Flexible(
                    child: Text(
                      'Generate something fresh',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(
                    Symbols.auto_awesome,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
