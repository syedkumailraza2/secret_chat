import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/recipe_provider.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/ingredient_chip.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_header.dart';
import 'preferences_screen.dart';

/// The pantry catalogue from create-ingredient.html.
class IngredientCategory {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  const IngredientCategory(this.title, this.icon, this.color, this.items);
}

const _catalogue = <IngredientCategory>[
  IngredientCategory('Vegetables', Symbols.eco, AppColors.primary, [
    'Tomato',
    'Onion',
    'Potato',
    'Carrot',
    'Capsicum',
  ]),
  IngredientCategory('Grains', Symbols.nutrition, AppColors.tertiaryContainer, [
    'Rice',
  ]),
  IngredientCategory(
      'Dairy & Eggs', Symbols.water_drop, AppColors.secondary, [
    'Paneer',
    'Eggs',
    'Milk',
  ]),
];

/// create-ingredient.html — "What do you have?"
class IngredientsScreen extends StatefulWidget {
  const IngredientsScreen({super.key});

  @override
  State<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends State<IngredientsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _continue() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PreferencesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipes = context.watch<RecipeProvider>();
    final query = recipes.searchQuery.trim().toLowerCase();

    // Filtering the catalogue in place keeps the category headings meaningful
    // while searching.
    final filtered = _catalogue
        .map((c) => IngredientCategory(
              c.title,
              c.icon,
              c.color,
              c.items
                  .where((i) => i.toLowerCase().contains(query))
                  .toList(),
            ))
        .where((c) => c.items.isNotEmpty)
        .toList();

    final catalogueNames =
        _catalogue.expand((c) => c.items).map((e) => e.toLowerCase()).toSet();
    final canAddCustom =
        query.isNotEmpty && !catalogueNames.contains(query);

    final selected = recipes.selectedIngredients.toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppTopBar(),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.margin,
              AppSpacing.lg,
              AppSpacing.margin,
              // Room for the floating CTA and the nav bar beneath it.
              BottomNavBar.reservedSpace(context) + 90,
            ),
            children: [
              Text('What do you have?', style: AppTextStyles.displayLg),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Select the ingredients you already have.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _IngredientSearch(
                controller: _searchController,
                onChanged: (v) =>
                    context.read<RecipeProvider>().setSearchQuery(v),
              ),
              if (canAddCustom) ...[
                const SizedBox(height: AppSpacing.sm),
                _AddCustomTile(
                  label: _searchController.text.trim(),
                  onTap: () {
                    context
                        .read<RecipeProvider>()
                        .addCustomIngredient(_searchController.text);
                    _searchController.clear();
                  },
                ),
              ],
              if (selected.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('You have', style: AppTextStyles.h3),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final item in selected)
                      SelectedIngredientChip(
                        label: item,
                        onRemove: () => context
                            .read<RecipeProvider>()
                            .removeIngredient(item),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              for (final category in filtered) ...[
                SectionHeader(
                  title: category.title,
                  icon: category.icon,
                  iconColor: category.color,
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final item in category.items)
                      IngredientChip(
                        label: item,
                        selected: recipes.isSelected(item),
                        onTap: () => context
                            .read<RecipeProvider>()
                            .toggleIngredient(item),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ],
          ),
          // Floating CTA, sitting above the bottom nav as in the design. The
          // fade behind it is the same treatment the onboarding footers use,
          // so scrolling chips don't get sliced by the button edge.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: true,
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppColors.background,
                      AppColors.background,
                      AppColors.background.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.margin,
            right: AppSpacing.margin,
            bottom: AppSpacing.md,
            child: PrimaryButton(
              label: 'Continue',
              pill: true,
              onPressed: selected.isEmpty ? null : _continue,
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientSearch extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _IngredientSearch({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppTextStyles.body,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        hintText: 'Search ingredients...',
        hintStyle: AppTextStyles.body.copyWith(
          color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        prefixIcon: const Icon(Symbols.search, color: AppColors.outline),
        filled: true,
        fillColor: AppColors.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          borderSide: const BorderSide(
            color: AppColors.primaryContainer,
            width: 2,
          ),
        ),
      ),
    );
  }
}

/// Lets someone add an ingredient the catalogue doesn't list, so the create
/// flow isn't limited to nine items.
class _AddCustomTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddCustomTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: AppColors.secondaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.normal),
        ),
        child: Row(
          children: [
            const Icon(Symbols.add, size: 18, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Add "$label"',
                style: AppTextStyles.small.copyWith(color: AppColors.primary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
