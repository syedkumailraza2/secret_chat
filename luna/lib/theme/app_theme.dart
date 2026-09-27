import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'text_styles.dart';

/// Spacing & radius tokens from the Tailwind config (1rem = 16px).
class AppSpacing {
  AppSpacing._();

  static const xs = 6.0; // space-xs
  static const sm = 12.0; // space-sm
  static const md = 20.0; // space-md
  static const lg = 32.0; // space-lg
  static const xl = 56.0; // space-xl
  static const gutter = 16.0;
  static const margin = 24.0; // page side padding
}

class AppRadius {
  AppRadius._();

  static const base = 16.0; // DEFAULT 1rem
  static const lg = 32.0;
  static const xl = 48.0;
  static const full = 9999.0;
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness b) {
    final scheme = ColorScheme(
      brightness: b,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.onPrimaryContainer,
      secondary: c.secondary,
      onSecondary: c.onSecondary,
      secondaryContainer: c.secondaryContainer,
      onSecondaryContainer: c.onSecondaryContainer,
      tertiary: c.tertiary,
      onTertiary: c.surface,
      error: c.error,
      onError: c.onError,
      errorContainer: c.errorContainer,
      onErrorContainer: c.onErrorContainer,
      surface: c.surface,
      onSurface: c.onSurface,
      onSurfaceVariant: c.onSurfaceVariant,
      surfaceContainerLowest: c.surfaceContainerLowest,
      surfaceContainerLow: c.surfaceContainerLow,
      surfaceContainer: c.surfaceContainer,
      surfaceContainerHigh: c.surfaceContainerHigh,
      surfaceContainerHighest: c.surfaceContainerHighest,
      outline: c.outline,
      outlineVariant: c.outlineVariant,
      inverseSurface: c.inverseSurface,
      onInverseSurface: c.inverseOnSurface,
      inversePrimary: c.primaryFixedDim,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.surface,
      fontFamily: AppText.sans,
      extensions: [c],
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerTheme: DividerThemeData(
        color: c.outlineVariant.withValues(alpha: 0.3),
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.surface : c.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? c.primaryContainer
              : c.surfaceContainerHigh,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.transparent
              : c.outlineVariant,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.inverseSurface,
        contentTextStyle: AppText.bodySm.copyWith(color: c.inverseOnSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.base),
        ),
      ),
    );
  }
}
