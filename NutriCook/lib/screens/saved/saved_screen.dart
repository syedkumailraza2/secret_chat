import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/saved_provider.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/error_view.dart';
import '../../widgets/recipe_card.dart';
import '../main_shell.dart';

/// save-recipe.html — filter chips over a two-column grid.
class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final saved = context.watch<SavedProvider>();
    final visible = saved.visible;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppTopBar(),
      body: SafeArea(
        top: false,
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.margin,
                AppSpacing.md,
                AppSpacing.margin,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Saved Recipes', style: AppTextStyles.displayLg),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Your curated collection of culinary inspirations.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: SavedProvider.filters.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (context, i) {
                          final label = SavedProvider.filters[i];
                          return CategoryChip(
                            label: label,
                            selected: saved.selectedFilter == label,
                            selectedColor: AppColors.primaryContainer,
                            textStyle: AppTextStyles.caption,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            onTap: () => context
                                .read<SavedProvider>()
                                .selectFilter(label),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
            if (visible.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyView(
                  icon: Symbols.bookmark,
                  title: saved.saved.isEmpty
                      ? 'Nothing saved yet'
                      : 'Nothing in this collection',
                  subtitle: saved.saved.isEmpty
                      ? 'Tap the bookmark on any recipe to keep it here.'
                      : 'Try another filter to see your other recipes.',
                  action: saved.saved.isEmpty
                      ? TextButton(
                          onPressed: () =>
                              MainShell.of(context)?.startCreateFlow(),
                          child: Text(
                            'Create a recipe',
                            style: AppTextStyles.h3.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : null,
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.margin,
                  0,
                  AppSpacing.margin,
                  BottomNavBar.reservedSpace(context) + AppSpacing.lg,
                ),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    // Two columns on phones, more as the window widens.
                    final width = constraints.crossAxisExtent;
                    final columns = width >= 900
                        ? 4
                        : width >= 620
                            ? 3
                            : 2;
                    // Sizing by explicit extent rather than an aspect ratio:
                    // the caption needs a near-constant ~110pt regardless of
                    // card width, and a fixed ratio starves it on a 320pt
                    // screen.
                    final itemWidth = (width -
                            (AppSpacing.gutter * (columns - 1))) /
                        columns;
                    final mainAxisExtent = itemWidth * 0.75 + 112;

                    return SliverGrid(
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: AppSpacing.gutter,
                        crossAxisSpacing: AppSpacing.gutter,
                        mainAxisExtent: mainAxisExtent,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final recipe = visible[i];
                          return CompactRecipeCard(
                            recipe: recipe,
                            isSaved: true,
                            onTap: () =>
                                AppRoutes.openRecipe(context, recipe),
                            onToggleSave: () => context
                                .read<SavedProvider>()
                                .toggleSave(recipe),
                          );
                        },
                        childCount: visible.length,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
