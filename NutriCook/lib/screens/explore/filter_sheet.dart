import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/browse_filters.dart';
import '../../providers/explore_provider.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/primary_button.dart';

/// The Explore filter sheet.
///
/// Edits a copy and hands it back on Apply, so backing out leaves the results
/// exactly as they were — half-applied filters would be worse than none.
class FilterSheet extends StatefulWidget {
  final BrowseFilters initial;

  const FilterSheet({super.key, required this.initial});

  /// Returns the new filters, or null when the sheet was dismissed.
  static Future<BrowseFilters?> show(
    BuildContext context,
    BrowseFilters initial,
  ) {
    return showModalBottomSheet<BrowseFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterSheet(initial: initial),
    );
  }

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late BrowseFilters _draft = widget.initial;

  static const _difficulties = ['Easy', 'Medium', 'Hard'];

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.margin,
                AppSpacing.md,
                AppSpacing.margin,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Filters', style: AppTextStyles.h2),
                  ),
                  if (!_draft.isEmpty)
                    TextButton(
                      onPressed: () =>
                          setState(() => _draft = const BrowseFilters()),
                      child: Text(
                        'Clear all',
                        style: AppTextStyles.small.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.margin,
                  AppSpacing.md,
                  AppSpacing.margin,
                  0,
                ),
                children: [
                  _Section(
                    title: 'Sort by',
                    child: _chips(
                      BrowseSort.values.map((s) => s.label).toList(),
                      selected: _draft.sort.label,
                      onTap: (label) => setState(() {
                        _draft = _draft.copyWith(
                          sort: BrowseSort.values
                              .firstWhere((s) => s.label == label),
                        );
                      }),
                    ),
                  ),
                  _Section(
                    title: 'Meal & goal',
                    child: _chips(
                      ExploreProvider.categories,
                      selected: _draft.category == null
                          ? null
                          : ExploreProvider.fromApiCategory(_draft.category!),
                      onTap: (label) => setState(() {
                        final value = ExploreProvider.toApiCategory(label);
                        _draft = _draft.category == value
                            ? _draft.copyWith(clearCategory: true)
                            : _draft.copyWith(category: value);
                      }),
                    ),
                  ),
                  _Section(
                    title: 'Cooking time',
                    child: _chips(
                      TimeFilter.values.map((t) => t.label).toList(),
                      selected: _draft.time.label,
                      onTap: (label) => setState(() {
                        _draft = _draft.copyWith(
                          time: TimeFilter.values
                              .firstWhere((t) => t.label == label),
                        );
                      }),
                    ),
                  ),
                  _Section(
                    title: 'Difficulty',
                    child: _chips(
                      _difficulties,
                      selected: _draft.difficulty,
                      onTap: (label) => setState(() {
                        _draft = _draft.difficulty == label
                            ? _draft.copyWith(clearDifficulty: true)
                            : _draft.copyWith(difficulty: label);
                      }),
                    ),
                  ),
                  _Section(
                    title: 'Nutrition',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Slider(
                          label: 'Max calories',
                          value: _draft.maxCalories,
                          min: 200,
                          max: 1200,
                          step: 50,
                          unit: 'kcal',
                          onChanged: (value) => setState(() {
                            _draft = value == null
                                ? _draft.copyWith(clearMaxCalories: true)
                                : _draft.copyWith(maxCalories: value);
                          }),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _Slider(
                          label: 'Min protein',
                          value: _draft.minProtein,
                          min: 10,
                          max: 80,
                          step: 5,
                          unit: 'g',
                          onChanged: (value) => setState(() {
                            _draft = value == null
                                ? _draft.copyWith(clearMinProtein: true)
                                : _draft.copyWith(minProtein: value);
                          }),
                        ),
                      ],
                    ),
                  ),
                  _Section(
                    title: 'Source',
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _draft.mineOnly,
                      activeThumbColor: AppColors.onPrimary,
                      activeTrackColor: AppColors.primaryContainer,
                      onChanged: (value) => setState(
                        () => _draft = _draft.copyWith(mineOnly: value),
                      ),
                      title: Text(
                        'Only my recipes',
                        style: AppTextStyles.body,
                      ),
                      subtitle: Text(
                        'Recipes you generated yourself.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.margin,
                AppSpacing.md,
                AppSpacing.margin,
                AppSpacing.md,
              ),
              child: PrimaryButton(
                label: 'Show recipes',
                icon: Symbols.tune,
                iconLeading: true,
                onPressed: () => Navigator.of(context).pop(_draft),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chips(
    List<String> labels, {
    required String? selected,
    required ValueChanged<String> onTap,
  }) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final label in labels)
          CategoryChip(
            label: label,
            selected: label == selected,
            selectedColor: AppColors.primaryContainer,
            textStyle: AppTextStyles.caption,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            onTap: () => onTap(label),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.onSurfaceVariant,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

/// A slider with an explicit "off" position, because "no maximum" is a
/// different thing from "the highest maximum".
class _Slider extends StatelessWidget {
  final String label;
  final int? value;
  final int min;
  final int max;
  final int step;
  final String unit;
  final ValueChanged<int?> onChanged;

  const _Slider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.unit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final active = value != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AppTextStyles.small)),
            Text(
              active ? '$value $unit' : 'Any',
              style: AppTextStyles.small.copyWith(
                color: active
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (active)
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => onChanged(null),
                icon: const Icon(
                  Symbols.close,
                  size: 18,
                  color: AppColors.onSurfaceVariant,
                ),
                tooltip: 'Clear',
              ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.primaryContainer,
            inactiveTrackColor: AppColors.surfaceVariant,
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withValues(alpha: 0.12),
            trackHeight: 4,
          ),
          child: Slider(
            value: (value ?? max).toDouble().clamp(
                  min.toDouble(),
                  max.toDouble(),
                ),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: ((max - min) / step).round(),
            onChanged: (next) => onChanged(next.round()),
          ),
        ),
      ],
    );
  }
}
