import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Type scale from the Tailwind config.
///
/// Families follow the config's `fontFamily` map exactly: Playfair Display
/// carries `display-lg`, `h1` and `h2`; Manrope carries `h3`, `body`, `small`
/// and `caption`.
///
/// Tailwind expresses line-height as a unitless multiplier and letter-spacing
/// in `em`; Flutter wants a multiplier for `height` and logical pixels for
/// `letterSpacing`, so the em values are multiplied out below.
class AppTextStyles {
  AppTextStyles._();

  static const String _serif = 'PlayfairDisplay';
  static const String _sans = 'Manrope';

  /// 32px / 1.2 / -0.02em / 700
  static const displayLg = TextStyle(
    fontFamily: _serif,
    fontSize: 32,
    height: 1.2,
    letterSpacing: -0.64,
    fontWeight: FontWeight.w700,
    color: AppColors.onBackground,
  );

  /// 28px / 1.3 / 700
  static const h1 = TextStyle(
    fontFamily: _serif,
    fontSize: 28,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AppColors.onBackground,
  );

  /// 22px / 1.4 / 700
  static const h2 = TextStyle(
    fontFamily: _serif,
    fontSize: 22,
    height: 1.4,
    fontWeight: FontWeight.w700,
    color: AppColors.onBackground,
  );

  /// 18px / 1.5 / 600
  static const h3 = TextStyle(
    fontFamily: _sans,
    fontSize: 18,
    height: 1.5,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );

  /// 16px / 1.6 / 400
  static const body = TextStyle(
    fontFamily: _sans,
    fontSize: 16,
    height: 1.6,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );

  /// 14px / 1.5 / 400
  static const small = TextStyle(
    fontFamily: _sans,
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );

  /// 12px / 1.4 / +0.01em / 500
  static const caption = TextStyle(
    fontFamily: _sans,
    fontSize: 12,
    height: 1.4,
    letterSpacing: 0.12,
    fontWeight: FontWeight.w500,
    color: AppColors.onSurface,
  );
}
