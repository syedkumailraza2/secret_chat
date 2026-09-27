import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_text_styles.dart';
import '../models/nutrition.dart';

/// The expandable "Nutrition per serving" card from reciepe-details.html:
/// large calorie figure, three macro pills, and a chevron that reveals fibre,
/// sugar, sodium and cholesterol.
class NutritionCard extends StatefulWidget {
  final Nutrition nutrition;

  const NutritionCard({super.key, required this.nutrition});

  @override
  State<NutritionCard> createState() => _NutritionCardState();
}

class _NutritionCardState extends State<NutritionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.nutrition;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Flexible so a larger text setting shrinks the heading
                // instead of overflowing the card.
                Flexible(
                  child: Text(
                    'Nutrition per serving',
                    style: AppTextStyles.h3,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: const Icon(
                    Symbols.expand_more,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${n.calories}',
                      style: AppTextStyles.displayLg.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    TextSpan(
                      text: ' kcal',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // The pills take all the remaining width and sit right-aligned,
              // as in the design. A Spacer here would halve that space and
              // push the third macro onto its own line.
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _macro('${n.protein.round()}g', 'Protein'),
                    _macro('${n.carbs.round()}g', 'Carbs'),
                    _macro('${n.fat.round()}g', 'Fat'),
                  ],
                ),
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Column(
                children: [
                  const Divider(color: AppColors.surfaceVariant),
                  const SizedBox(height: AppSpacing.sm),
                  _detailRow('Fiber', '${n.fiber.round()}g',
                      'Sugar', '${n.sugar.round()}g'),
                  const SizedBox(height: AppSpacing.sm),
                  _detailRow('Sodium', '${n.sodium.round()}mg',
                      'Cholesterol', '${n.cholesterol.round()}mg'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _macro(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTextStyles.caption.copyWith(color: AppColors.primary),
          ),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String l1, String v1, String l2, String v2) {
    return Row(
      children: [
        Expanded(child: _detail(l1, v1)),
        const SizedBox(width: AppSpacing.lg),
        Expanded(child: _detail(l2, v2)),
      ],
    );
  }

  Widget _detail(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.small.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
