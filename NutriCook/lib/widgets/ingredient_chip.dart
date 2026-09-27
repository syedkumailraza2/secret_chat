import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_text_styles.dart';

/// A pantry ingredient chip. Outlined when unselected; filled with a leading
/// check when selected, exactly as `create-ingredient.html` styles it.
class IngredientChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const IngredientChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryContainer : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: selected
                ? AppColors.primaryContainer
                : AppColors.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The check only occupies space once selected, so unselected chips
            // stay compact like the design.
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: selected
                  ? const Padding(
                      padding: EdgeInsets.only(right: AppSpacing.sm),
                      child: Icon(
                        Symbols.check,
                        size: 16,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Text(
              label,
              style: AppTextStyles.small.copyWith(
                color:
                    selected ? AppColors.onPrimary : AppColors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The removable chip shown in the "You have" summary row.
class SelectedIngredientChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const SelectedIngredientChip({
    super.key,
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Symbols.close,
              size: 14,
              color: AppColors.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
