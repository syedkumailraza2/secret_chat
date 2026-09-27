import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_text_styles.dart';

/// The pill filter used on the home category row, the saved-recipes filters and
/// the meal picker.
class CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// home.html fills the selected chip with `primary`; save-recipe.html and
  /// create-preference.html use `primary-container`.
  final Color selectedColor;

  final TextStyle? textStyle;
  final EdgeInsets padding;

  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor = AppColors.primary,
    this.textStyle,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final base = textStyle ?? AppTextStyles.small;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: padding,
        decoration: BoxDecoration(
          color: selected ? selectedColor : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: selected ? selectedColor : AppColors.outlineVariant,
          ),
          boxShadow: selected ? AppShadows.soft : null,
        ),
        child: Text(
          label,
          style: base.copyWith(
            color: selected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
