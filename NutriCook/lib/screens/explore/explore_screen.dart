import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/explore_provider.dart';
import '../../providers/saved_provider.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/error_view.dart';
import '../../widgets/recipe_card.dart';
import '../main_shell.dart';
import 'filter_sheet.dart';
import '../../widgets/secret_trigger.dart';

/// Explore — everything the community has generated.
///
/// Laid out like save-recipe.html: a headline, a chip row, and a two-column
/// grid of compact cards. The filter button and the results count are the two
/// additions a library of this size needs.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _loadedOnce = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The shell builds every tab up front, so the first load waits until the
    // screen is actually in the tree rather than firing at app start.
    if (!_loadedOnce) {
      _loadedOnce = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<ExploreProvider>().load();
      });
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Fetch a screen's worth early so the grid rarely shows its spinner.
    if (position.pixels >= position.maxScrollExtent - 600) {
      context.read<ExploreProvider>().loadMore();
    }
  }

  Future<void> _openFilters() async {
    final explore = context.read<ExploreProvider>();
    final next = await FilterSheet.show(context, explore.filters);
    if (next == null || !mounted) return;

    // The sheet can change the search term via "clear all", so the field has
    // to follow it back.
    if (next.query != _searchController.text) {
      _searchController.text = next.query;
    }
    await explore.applyFilters(next);
  }

  @override
  Widget build(BuildContext context) {
    final explore = context.watch<ExploreProvider>();
    final saved = context.watch<SavedProvider>();

    return Scaffold(
      backgroundColor: AppColors.backgroundEditorial,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => context.read<ExploreProvider>().load(),
          color: AppColors.primary,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.margin,
                  AppSpacing.lg,
                  AppSpacing.margin,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SecretTrigger(
                        child: Text('Explore', style: AppTextStyles.displayLg),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Every recipe the community has cooked up.',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _SearchRow(
                        controller: _searchController,
                        activeFilters: explore.filters.activeCount,
                        onChanged: (value) =>
                            context.read<ExploreProvider>().setQuery(value),
                        onOpenFilters: _openFilters,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: ExploreProvider.categories.length + 1,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: AppSpacing.sm),
                          itemBuilder: (context, i) {
                            if (i == 0) {
                              return CategoryChip(
                                label: 'All',
                                selected: explore.filters.category == null,
                                selectedColor: AppColors.primaryContainer,
                                textStyle: AppTextStyles.caption,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                                onTap: () => context
                                    .read<ExploreProvider>()
                                    .setCategory(null),
                              );
                            }
                            final label = ExploreProvider.categories[i - 1];
                            final value =
                                ExploreProvider.toApiCategory(label);
                            return CategoryChip(
                              label: label,
                              selected: explore.filters.category == value,
                              selectedColor: AppColors.primaryContainer,
                              textStyle: AppTextStyles.caption,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              onTap: () => context
                                  .read<ExploreProvider>()
                                  .setCategory(
                                    explore.filters.category == value
                                        ? null
                                        : value,
                                  ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (!explore.isLoading && explore.error == null)
                        Text(
                          _resultsLabel(explore),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),
              if (explore.isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  ),
                )
              else if (explore.error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorView(
                    message: explore.error!,
                    onRetry: () => context.read<ExploreProvider>().load(),
                  ),
                )
              else if (explore.recipes.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyView(
                    icon: Symbols.explore,
                    title: explore.filters.isEmpty
                        ? 'Nothing here yet'
                        : 'No matches',
                    subtitle: explore.filters.isEmpty
                        ? 'Generated recipes show up here for everyone to '
                            'browse. Be the first to make one.'
                        : AppMessages.browseEmpty,
                    action: explore.filters.isEmpty
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
                        : TextButton(
                            onPressed: () {
                              _searchController.clear();
                              context.read<ExploreProvider>().clearFilters();
                            },
                            child: Text(
                              'Clear filters',
                              style: AppTextStyles.h3.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.margin,
                  ),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      // Two columns on phones, more as the window widens —
                      // the same treatment as the saved grid.
                      final width = constraints.crossAxisExtent;
                      final columns = width >= 900
                          ? 4
                          : width >= 620
                              ? 3
                              : 2;
                      final itemWidth =
                          (width - (AppSpacing.gutter * (columns - 1))) /
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
                            final recipe = explore.recipes[i];
                            return CompactRecipeCard(
                              recipe: recipe,
                              isSaved: saved.isSaved(recipe.id),
                              onTap: () =>
                                  AppRoutes.openRecipe(context, recipe),
                              onToggleSave: () => context
                                  .read<SavedProvider>()
                                  .toggleSave(recipe),
                            );
                          },
                          childCount: explore.recipes.length,
                        ),
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: AppSpacing.lg,
                      bottom: BottomNavBar.reservedSpace(context) +
                          AppSpacing.lg,
                    ),
                    child: Center(
                      child: explore.isLoadingMore
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppColors.primary,
                              ),
                            )
                          : explore.hasMore
                              ? const SizedBox.shrink()
                              : Text(
                                  "That's everything.",
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _resultsLabel(ExploreProvider explore) {
    if (explore.total == 0) return 'No recipes';
    final noun = explore.total == 1 ? 'recipe' : 'recipes';
    return explore.filters.isEmpty
        ? '${explore.total} $noun'
        : '${explore.total} $noun match';
  }
}

/// The search field with the filter button beside it.
class _SearchRow extends StatelessWidget {
  final TextEditingController controller;
  final int activeFilters;
  final ValueChanged<String> onChanged;
  final VoidCallback onOpenFilters;

  const _SearchRow({
    required this.controller,
    required this.activeFilters,
    required this.onChanged,
    required this.onOpenFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: AppTextStyles.body,
            cursorColor: AppColors.primary,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search recipes',
              hintStyle: AppTextStyles.body.copyWith(
                color: AppColors.onSecondaryContainer,
              ),
              prefixIcon: const Icon(
                Symbols.search,
                size: 20,
                color: AppColors.onSurfaceVariant,
              ),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(
                        Symbols.close,
                        size: 18,
                        color: AppColors.onSurfaceVariant,
                      ),
                      tooltip: 'Clear search',
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    ),
              filled: true,
              fillColor: AppColors.surfaceContainer,
              contentPadding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        GestureDetector(
          onTap: onOpenFilters,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: activeFilters > 0
                  ? AppColors.primaryContainer
                  : AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Symbols.tune,
                  size: 22,
                  color: activeFilters > 0
                      ? AppColors.onPrimary
                      : AppColors.onSurfaceVariant,
                ),
                if (activeFilters > 0)
                  Positioned(
                    top: 8,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.tertiaryFixedDim,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$activeFilters',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 9,
                          height: 1,
                          color: AppColors.onTertiaryFixed,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
