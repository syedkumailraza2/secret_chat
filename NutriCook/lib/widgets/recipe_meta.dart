import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_text_styles.dart';

/// The rounded pill that floats over recipe photography showing a single
/// nutrition figure ("450 kcal", "32g Protein").
class NutritionBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  const NutritionBadge({
    super.key,
    required this.icon,
    required this.label,
    this.background = AppColors.nutritionBadge,
    this.foreground = AppColors.onPrimaryFixedVariant,
  });

  const NutritionBadge.calories(int calories, {super.key})
      : icon = Symbols.local_fire_department,
        label = '$calories kcal',
        background = AppColors.nutritionBadge,
        foreground = AppColors.onPrimaryFixedVariant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

/// The dot-separated metadata line: time • difficulty • servings.
class MetaRow extends StatelessWidget {
  final int? cookingTime;
  final String? difficulty;
  final int? servings;
  final Color color;
  final TextStyle? style;

  /// reciepe-details.html shows the full signal glyph whatever the difficulty,
  /// while the result cards grade it by level. Defaults to the graded form.
  final bool gradeDifficultyIcon;

  const MetaRow({
    super.key,
    this.cookingTime,
    this.difficulty,
    this.servings,
    this.color = AppColors.onSurfaceVariant,
    this.style,
    this.gradeDifficultyIcon = true,
  });

  /// Difficulty maps to a signal-strength icon in the design: one bar for
  /// Easy, two for Medium, three for Hard.
  IconData get _difficultyIcon {
    if (!gradeDifficultyIcon) return Symbols.signal_cellular_alt;
    return switch (difficulty?.toLowerCase()) {
      'medium' => Symbols.signal_cellular_alt_2_bar,
      'hard' => Symbols.signal_cellular_alt,
      _ => Symbols.signal_cellular_alt_1_bar,
    };
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = (style ?? AppTextStyles.small).copyWith(color: color);

    final items = <Widget>[
      if (cookingTime != null && cookingTime! > 0)
        _item(Symbols.schedule, '$cookingTime min', textStyle),
      if (difficulty != null && difficulty!.isNotEmpty)
        _item(_difficultyIcon, difficulty!, textStyle),
      if (servings != null && servings! > 0)
        _item(Symbols.restaurant, '$servings servings', textStyle),
    ];

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.outlineVariant,
                shape: BoxShape.circle,
              ),
            ),
          items[i],
        ],
      ],
    );
  }

  Widget _item(IconData icon, String label, TextStyle style) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: style),
      ],
    );
  }
}
