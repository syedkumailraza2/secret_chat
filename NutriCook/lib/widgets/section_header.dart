import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_text_styles.dart';

/// The "icon + title" heading used above each section on create-preference,
/// profile and the ingredient categories.
class SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color iconColor;
  final TextStyle? style;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.iconColor = AppColors.primaryContainer,
    this.style,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 22, color: iconColor, fill: 1),
          const SizedBox(width: AppSpacing.xs),
        ],
        Expanded(
          child: Text(title, style: style ?? AppTextStyles.h3),
        ),
        ?trailing,
      ],
    );
  }
}
