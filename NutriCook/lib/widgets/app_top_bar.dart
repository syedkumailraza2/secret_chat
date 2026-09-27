import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_text_styles.dart';
import 'secret_trigger.dart';

/// The "menu — NutriCook — avatar" bar shared by the inner screens.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onLeading;
  final VoidCallback? onAvatar;

  /// Onboarding uses a back arrow here instead of the hamburger.
  final IconData leadingIcon;

  /// Some screens show a plain spacer where the avatar would be.
  final bool showAvatar;

  final Widget? bottom;

  const AppTopBar({
    super.key,
    this.onLeading,
    this.onAvatar,
    this.leadingIcon = Symbols.menu,
    this.showAvatar = true,
    this.bottom,
  });

  @override
  Size get preferredSize => Size.fromHeight(bottom == null ? 56 : 60);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.margin,
                ),
                child: Row(
                  children: [
                    _iconButton(leadingIcon, onLeading),
                    Expanded(
                      child: SecretTrigger(
                        child: Text(
                          'NutriCook',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.h1.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    if (showAvatar)
                      GestureDetector(
                        onTap: onAvatar,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceContainer,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Symbols.person,
                            size: 20,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 32),
                  ],
                ),
              ),
            ),
            ?bottom,
          ],
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback? onTap) {
    return SizedBox(
      width: 32,
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Icon(icon, color: AppColors.primary, size: 24),
      ),
    );
  }
}
