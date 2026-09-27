import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_text_styles.dart';
import 'recipe_image.dart';

/// The horizontal option row used on the goal and diet onboarding steps:
/// circular icon, title, subtitle, and a radio circle that fills on select.
class SelectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const SelectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.onPrimaryContainer
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.normal),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected ? AppShadows.raised : AppShadows.soft,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
                fill: 1,
                color: AppColors.primaryContainer,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: AppTextStyles.small.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _RadioDot(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  final bool selected;

  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        border: Border.all(
          color: selected ? Colors.transparent : AppColors.outlineVariant,
          width: 2,
        ),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0.5,
        duration: const Duration(milliseconds: 200),
        child: AnimatedOpacity(
          opacity: selected ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: const Icon(
            Symbols.check_circle,
            size: 24,
            fill: 1,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// The square icon tile used for allergy selection: circular icon above a
/// label, filling with primary when selected.
class TileCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const TileCard({
    super.key,
    required this.icon,
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
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryContainer
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.normal),
          border: Border.all(
            color: selected
                ? AppColors.primaryContainer
                : AppColors.outlineVariant,
          ),
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.transparent
                    : AppColors.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: selected ? AppColors.onPrimary : AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.h3.copyWith(
                color: selected ? AppColors.onPrimary : AppColors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The photographic cuisine tile: image, gradient scrim, label, and a check
/// badge that appears on selection.
class ImageTileCard extends StatelessWidget {
  final String? imageUrl;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// The "Anything" tile has no photograph — it shows an icon on a tinted
  /// surface instead.
  final IconData? fallbackIcon;

  const ImageTileCard({
    super.key,
    required this.imageUrl,
    required this.label,
    required this.selected,
    required this.onTap,
    this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, selected ? -4 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.normal),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.surfaceVariant,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? AppShadows.raised : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (fallbackIcon != null)
              Container(
                color: AppColors.surfaceContainerHigh,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(fallbackIcon, size: 32, color: AppColors.primary),
                    const SizedBox(height: AppSpacing.sm),
                    Text(label, style: AppTextStyles.h3),
                  ],
                ),
              )
            else ...[
              RecipeImage(url: imageUrl),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: selected
                        ? [
                            AppColors.primary.withValues(alpha: 0.9),
                            AppColors.primary.withValues(alpha: 0.3),
                          ]
                        : [
                            AppColors.inverseSurface.withValues(alpha: 0.8),
                            Colors.transparent,
                          ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    label,
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.onPrimary,
                      shadows: const [
                        Shadow(
                          color: Color(0x66000000),
                          blurRadius: 6,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: AnimatedScale(
                scale: selected ? 1 : 0.75,
                duration: const Duration(milliseconds: 300),
                child: AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Symbols.check,
                      size: 16,
                      fill: 1,
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
