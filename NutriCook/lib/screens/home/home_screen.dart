import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/recipe.dart';
import '../../providers/home_provider.dart';
import '../../providers/saved_provider.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/error_view.dart';
import '../../widgets/recipe_card.dart';
import '../../widgets/section_header.dart';
import '../main_shell.dart';
import '../../widgets/secret_trigger.dart';

/// home.html — greeting, category chips, featured card, AI card.
///
/// The design's search field is deliberately absent: searching lives on
/// Explore, which queries the whole library server-side rather than filtering
/// the handful of recipes this screen happens to have paged in.
///
/// Below those sits the rest of the feed, which the design does not show: the
/// shuffled public feed now arrives ten at a time and keeps going as you
/// scroll, and a screen that fetched ten recipes to display one would be a
/// strange thing to build.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 600) {
      context.read<HomeProvider>().loadMore();
    }
  }

  /// The design reads "Good evening"; keeping it fixed would be wrong at
  /// 9am, so the salutation follows the clock.
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    final saved = context.watch<SavedProvider>();

    final featured = home.recipes.isEmpty ? null : home.recipes.first;
    final rest =
        home.recipes.length > 1 ? home.recipes.sublist(1) : const <Recipe>[];

    return Scaffold(
      backgroundColor: AppColors.backgroundEditorial,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => context.read<HomeProvider>().load(),
          color: AppColors.primary,
          child: ListView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.margin,
              AppSpacing.lg,
              AppSpacing.margin,
              BottomNavBar.reservedSpace(context) + AppSpacing.lg,
            ),
            children: [
              SecretTrigger(
                child: Text(
                  '$_greeting 👋\nWhat are you cooking today?',
                  style: AppTextStyles.displayLg,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _CategoryRow(
                categories: HomeProvider.categories,
                selected: home.selectedCategory,
                onSelect: (c) =>
                    context.read<HomeProvider>().selectCategory(c),
              ),
              const SizedBox(height: AppSpacing.md),
              if (home.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  ),
                )
              else if (home.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.xl,
                  ),
                  child: ErrorView(
                    message: home.error!,
                    onRetry: () => context.read<HomeProvider>().load(),
                  ),
                )
              else if (featured == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  child: EmptyView(
                    icon: Symbols.local_dining,
                    title: 'Nothing here yet',
                    subtitle: 'Try another category, or create a recipe of '
                        'your own.',
                  ),
                )
              else
                FeaturedRecipeCard(
                  recipe: featured,
                  isSaved: saved.isSaved(featured.id),
                  onTap: () => AppRoutes.openRecipe(context, featured),
                  onToggleSave: () =>
                      context.read<SavedProvider>().toggleSave(featured),
                ),
              const SizedBox(height: AppSpacing.md),
              const _AiCard(),
              if (rest.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                SectionHeader(
                  title: 'More to cook',
                  icon: Symbols.local_dining,
                  style: AppTextStyles.h2,
                ),
                const SizedBox(height: AppSpacing.md),
                for (final recipe in rest) ...[
                  RecipeCard(
                    recipe: recipe,
                    isSaved: saved.isSaved(recipe.id),
                    onTap: () => AppRoutes.openRecipe(context, recipe),
                    onToggleSave: () =>
                        context.read<SavedProvider>().toggleSave(recipe),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ],
              if (home.recipes.isNotEmpty)
                _FeedFooter(
                  isLoadingMore: home.isLoadingMore,
                  hasMore: home.hasMore,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The spinner, or the full stop, at the end of the feed.
class _FeedFooter extends StatelessWidget {
  final bool isLoadingMore;
  final bool hasMore;

  const _FeedFooter({required this.isLoadingMore, required this.hasMore});

  @override
  Widget build(BuildContext context) {
    if (hasMore && !isLoadingMore) return const SizedBox(height: AppSpacing.md);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: isLoadingMore
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.primary,
                ),
              )
            : Text(
                "You've reached the end — pull down for a fresh shuffle.",
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelect;

  const _CategoryRow({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final label = categories[i];
          return CategoryChip(
            label: label,
            selected: label == selected,
            onTap: () => onSelect(label),
          );
        },
      ),
    );
  }
}

/// The "What do you have at home?" card that starts the create flow.
class _AiCard extends StatelessWidget {
  const _AiCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.secondaryContainer,
            AppColors.surfaceContainerHigh,
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Symbols.magic_button,
              size: 24,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('What do you have at home?', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Let our culinary AI craft a perfect meal from your pantry '
            'ingredients.',
            style: AppTextStyles.small.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          GestureDetector(
            onTap: () => MainShell.of(context)?.startCreateFlow(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.full),
                boxShadow: AppShadows.active,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Create Recipe',
                    style: AppTextStyles.h3
                        .copyWith(color: AppColors.onPrimary),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(
                    Symbols.magic_button,
                    size: 20,
                    color: AppColors.onPrimary,
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
