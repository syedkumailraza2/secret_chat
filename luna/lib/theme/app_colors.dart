import 'package:flutter/material.dart';

/// Design tokens ported verbatim from the Tailwind config in luna-UI/*.html.
/// Access in widgets via `context.colors` (see extension at the bottom).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.primaryFixed,
    required this.primaryFixedDim,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.secondaryFixed,
    required this.secondaryFixedDim,
    required this.tertiary,
    required this.tertiaryContainer,
    required this.tertiaryFixed,
    required this.tertiaryFixedDim,
    required this.surface,
    required this.surfaceDim,
    required this.surfaceBright,
    required this.surfaceVariant,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.inverseSurface,
    required this.inverseOnSurface,
    required this.outline,
    required this.outlineVariant,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
  });

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color primaryFixed;
  final Color primaryFixedDim;
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color secondaryFixed;
  final Color secondaryFixedDim;
  final Color tertiary;
  final Color tertiaryContainer;
  final Color tertiaryFixed;
  final Color tertiaryFixedDim;
  final Color surface;
  final Color surfaceDim;
  final Color surfaceBright;
  final Color surfaceVariant;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color inverseSurface;
  final Color inverseOnSurface;
  final Color outline;
  final Color outlineVariant;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;

  // Phase accents, matching the Today timeline segments in the design.
  Color get menstrual => secondaryContainer;
  Color get follicular => primaryContainer;
  Color get ovulation => tertiaryFixedDim;
  Color get luteal => surfaceVariant;

  static const light = AppColors(
    primary: Color(0xFF2F0211),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF4A1525),
    onPrimaryContainer: Color(0xFFC57A8B),
    primaryFixed: Color(0xFFFFD9DF),
    primaryFixedDim: Color(0xFFFFB1C2),
    secondary: Color(0xFF7E525C),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFEC6D1),
    onSecondaryContainer: Color(0xFF7A4F5A),
    secondaryFixed: Color(0xFFFFD9E0),
    secondaryFixedDim: Color(0xFFEFB8C4),
    tertiary: Color(0xFF0E150A),
    tertiaryContainer: Color(0xFF222A1E),
    tertiaryFixed: Color(0xFFDCE6D3),
    tertiaryFixedDim: Color(0xFFC0C9B8),
    surface: Color(0xFFFFF8F7),
    surfaceDim: Color(0xFFE3D7D8),
    surfaceBright: Color(0xFFFFF8F7),
    surfaceVariant: Color(0xFFECE0E1),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFDF1F2),
    surfaceContainer: Color(0xFFF8EBEC),
    surfaceContainerHigh: Color(0xFFF2E5E6),
    surfaceContainerHighest: Color(0xFFECE0E1),
    onSurface: Color(0xFF201A1B),
    onSurfaceVariant: Color(0xFF524346),
    inverseSurface: Color(0xFF362F30),
    inverseOnSurface: Color(0xFFFBEEEF),
    outline: Color(0xFF847375),
    outlineVariant: Color(0xFFD7C1C4),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF93000A),
  );

  static const dark = AppColors(
    primary: Color(0xFFFFB1C3),
    onPrimary: Color(0xFF561B2E),
    primaryContainer: Color(0xFFC9798E),
    onPrimaryContainer: Color(0xFF4E1528),
    primaryFixed: Color(0xFFFFD9E0),
    primaryFixedDim: Color(0xFFFFB1C3),
    secondary: Color(0xFFFFB1C3),
    onSecondary: Color(0xFF5F102D),
    secondaryContainer: Color(0xFF7C2843),
    onSecondaryContainer: Color(0xFFFF96B1),
    secondaryFixed: Color(0xFFFFD9E0),
    secondaryFixedDim: Color(0xFFFFB1C3),
    tertiary: Color(0xFFFFB1C5),
    tertiaryContainer: Color(0xFFC47C8F),
    tertiaryFixed: Color(0xFFFFD9E1),
    tertiaryFixedDim: Color(0xFFFFB1C5),
    surface: Color(0xFF151314),
    surfaceDim: Color(0xFF151314),
    surfaceBright: Color(0xFF3C3839),
    surfaceVariant: Color(0xFF383435),
    surfaceContainerLowest: Color(0xFF100D0E),
    surfaceContainerLow: Color(0xFF1E1B1C),
    surfaceContainer: Color(0xFF221F20),
    surfaceContainerHigh: Color(0xFF2D292A),
    surfaceContainerHighest: Color(0xFF383435),
    onSurface: Color(0xFFE8E1E2),
    onSurfaceVariant: Color(0xFFD7C1C5),
    inverseSurface: Color(0xFFE8E1E2),
    inverseOnSurface: Color(0xFF332F30),
    outline: Color(0xFF9F8C8F),
    outlineVariant: Color(0xFF524346),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      primaryContainer: l(primaryContainer, other.primaryContainer),
      onPrimaryContainer: l(onPrimaryContainer, other.onPrimaryContainer),
      primaryFixed: l(primaryFixed, other.primaryFixed),
      primaryFixedDim: l(primaryFixedDim, other.primaryFixedDim),
      secondary: l(secondary, other.secondary),
      onSecondary: l(onSecondary, other.onSecondary),
      secondaryContainer: l(secondaryContainer, other.secondaryContainer),
      onSecondaryContainer: l(onSecondaryContainer, other.onSecondaryContainer),
      secondaryFixed: l(secondaryFixed, other.secondaryFixed),
      secondaryFixedDim: l(secondaryFixedDim, other.secondaryFixedDim),
      tertiary: l(tertiary, other.tertiary),
      tertiaryContainer: l(tertiaryContainer, other.tertiaryContainer),
      tertiaryFixed: l(tertiaryFixed, other.tertiaryFixed),
      tertiaryFixedDim: l(tertiaryFixedDim, other.tertiaryFixedDim),
      surface: l(surface, other.surface),
      surfaceDim: l(surfaceDim, other.surfaceDim),
      surfaceBright: l(surfaceBright, other.surfaceBright),
      surfaceVariant: l(surfaceVariant, other.surfaceVariant),
      surfaceContainerLowest: l(surfaceContainerLowest, other.surfaceContainerLowest),
      surfaceContainerLow: l(surfaceContainerLow, other.surfaceContainerLow),
      surfaceContainer: l(surfaceContainer, other.surfaceContainer),
      surfaceContainerHigh: l(surfaceContainerHigh, other.surfaceContainerHigh),
      surfaceContainerHighest: l(surfaceContainerHighest, other.surfaceContainerHighest),
      onSurface: l(onSurface, other.onSurface),
      onSurfaceVariant: l(onSurfaceVariant, other.onSurfaceVariant),
      inverseSurface: l(inverseSurface, other.inverseSurface),
      inverseOnSurface: l(inverseOnSurface, other.inverseOnSurface),
      outline: l(outline, other.outline),
      outlineVariant: l(outlineVariant, other.outlineVariant),
      error: l(error, other.error),
      onError: l(onError, other.onError),
      errorContainer: l(errorContainer, other.errorContainer),
      onErrorContainer: l(onErrorContainer, other.onErrorContainer),
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
