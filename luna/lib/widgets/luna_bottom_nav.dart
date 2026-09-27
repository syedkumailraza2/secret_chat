import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';

/// Bottom navigation bar from the shared design component:
/// blurred surface, hairline top border, active tab = filled icon + dot.
class LunaBottomNav extends StatelessWidget {
  const LunaBottomNav({super.key, required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Symbols.calendar_today, 'Today'),
    (Symbols.calendar_month, 'Calendar'),
    (Symbols.auto_awesome, 'Insights'),
    (Symbols.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.9),
            border: Border(top: BorderSide(color: c.outlineVariant.withValues(alpha: 0.3))),
          ),
          padding: EdgeInsets.only(
            left: AppSpacing.margin,
            right: AppSpacing.margin,
            top: AppSpacing.xs,
            bottom: AppSpacing.md + MediaQuery.paddingOf(context).bottom * 0.5,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < _items.length; i++)
                _NavItem(
                  icon: _items[i].$1,
                  label: _items[i].$2,
                  active: i == index,
                  onTap: () => onTap(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = active ? c.primary : c.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color, fill: active ? 1 : 0, weight: 200),
              const SizedBox(height: 2),
              Text(label, style: AppText.labelSm.copyWith(color: color).weight(active ? 600 : 500)),
              const SizedBox(height: 4),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: active ? c.primary : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
