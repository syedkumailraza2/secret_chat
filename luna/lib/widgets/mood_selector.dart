import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';
import '../utils/constants.dart';

/// Horizontally scrolling single-select mood tiles (icon + label).
/// Tapping the selected tile again clears the selection (`onChanged(null)`).
class MoodSelector extends StatelessWidget {
  const MoodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.margin),
  });

  final String? selected;
  final ValueChanged<String?> onChanged;

  /// Horizontal inset of the scroll row; the row itself bleeds edge to edge.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding.add(const EdgeInsets.symmetric(vertical: 4)),
      child: Row(
        children: [
          for (final o in moodOptions) ...[
            if (o != moodOptions.first) const SizedBox(width: 10),
            _MoodTile(
              option: o,
              selected: o.id == selected,
              onTap: () => onChanged(o.id == selected ? null : o.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoodTile extends StatelessWidget {
  const _MoodTile({required this.option, required this.selected, required this.onTap});

  final Option option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minWidth: 70),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? c.primaryContainer : c.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.base),
            border: Border.all(
              color: selected ? Colors.transparent : c.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                option.icon ?? Symbols.mood,
                size: 24,
                weight: 300,
                color: selected ? c.onPrimary : c.secondary,
              ),
              const SizedBox(height: 4),
              Text(
                option.label,
                style: AppText.labelSm.copyWith(
                  color: selected ? c.onPrimary : c.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
