import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_text_styles.dart';

enum NavTab { home, explore, create, saved, profile }

/// The tab bar from the designs: blurred translucent surface, rounded top
/// corners, filled icon on the active tab.
///
/// A deliberate departure: the HTML shows four tabs, and this has five. Explore
/// is a destination in its own right — a library of everything the community
/// has generated — and burying it behind a link on Home would have hidden the
/// larger half of the app. The treatment of each tab is unchanged.
///
/// Mobile only — every HTML file hides it at the `md:` breakpoint.
class BottomNavBar extends StatelessWidget {
  final NavTab current;
  final ValueChanged<NavTab> onTap;

  const BottomNavBar({
    super.key,
    required this.current,
    required this.onTap,
  });

  /// The bar's visual height, before the device's bottom safe area.
  static const double height = 68;

  /// Total space a scrolling screen must reserve so content clears the bar.
  static double reservedSpace(BuildContext context) =>
      height + MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.card),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.only(
            top: 10,
            bottom: bottomInset > 0 ? bottomInset : 12,
            // Tighter than the four-tab design's 16pt, so five labels still
            // clear each other on a 320pt screen.
            left: AppSpacing.sm,
            right: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.85),
            boxShadow: AppShadows.bottomNav,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _item(NavTab.home, Symbols.home, 'Home'),
              _item(NavTab.explore, Symbols.explore, 'Explore'),
              _item(NavTab.create, Symbols.magic_button, 'Create'),
              _item(NavTab.saved, Symbols.bookmark, 'Saved'),
              _item(NavTab.profile, Symbols.person, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(NavTab tab, IconData icon, String label) {
    final active = tab == current;
    final color =
        active ? AppColors.primary : AppColors.onSecondaryContainer;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(tab),
        borderRadius: BorderRadius.circular(AppRadius.normal),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24, fill: active ? 1 : 0),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  // The caption's +0.01em tracking is what pushes "Explore"
                  // past its slot at five tabs; the labels read fine without
                  // it at this size.
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
