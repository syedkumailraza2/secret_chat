import 'package:flutter/material.dart';

/// Design tokens extracted verbatim from the Tailwind config shared by every
/// file in `nutricook-UI/`. Do not invent colours; if a shade is needed that is
/// not here, it is not in the design.
class AppColors {
  AppColors._();

  // Primary
  static const primary = Color(0xFF256441);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFF3F7D58);
  static const onPrimaryContainer = Color(0xFFDCFFE4);
  static const primaryFixed = Color(0xFFAFF1C4);
  static const primaryFixedDim = Color(0xFF94D5AA);
  static const onPrimaryFixed = Color(0xFF002110);
  static const onPrimaryFixedVariant = Color(0xFF0D5130);
  static const inversePrimary = Color(0xFF94D5AA);

  // Secondary
  static const secondary = Color(0xFF56615A);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFDAE5DC);
  static const onSecondaryContainer = Color(0xFF5C6760);
  static const secondaryFixed = Color(0xFFDAE5DC);
  static const secondaryFixedDim = Color(0xFFBEC9C1);
  static const onSecondaryFixed = Color(0xFF141E18);
  static const onSecondaryFixedVariant = Color(0xFF3F4943);

  // Tertiary
  static const tertiary = Color(0xFF775100);
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFF976800);
  static const onTertiaryContainer = Color(0xFFFFF5EB);
  static const tertiaryFixed = Color(0xFFFFDEAD);
  static const tertiaryFixedDim = Color(0xFFFABC4E);
  static const onTertiaryFixed = Color(0xFF281900);
  static const onTertiaryFixedVariant = Color(0xFF604100);

  // Error
  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  // Background & surface
  static const background = Color(0xFFFCF9F8);
  static const onBackground = Color(0xFF1B1B1B);
  static const surface = Color(0xFFFCF9F8);
  static const onSurface = Color(0xFF1B1B1B);
  static const surfaceVariant = Color(0xFFE5E2E1);
  static const onSurfaceVariant = Color(0xFF404942);
  static const surfaceBright = Color(0xFFFCF9F8);
  static const surfaceDim = Color(0xFFDCD9D9);
  static const surfaceTint = Color(0xFF2B6A47);
  static const inverseSurface = Color(0xFF313030);
  static const inverseOnSurface = Color(0xFFF3F0EF);

  // Surface containers
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF6F3F2);
  static const surfaceContainer = Color(0xFFF0EDED);
  static const surfaceContainerHigh = Color(0xFFEAE7E7);
  static const surfaceContainerHighest = Color(0xFFE5E2E1);

  // Outline
  static const outline = Color(0xFF707971);
  static const outlineVariant = Color(0xFFC0C9BF);

  /// home.html and onboarding4.html override the body background with this
  /// warmer off-white for the "editorial feel".
  static const backgroundEditorial = Color(0xFFFAF9F5);

  /// The tinted pill background used behind nutrition badges on AI-result.html.
  static const nutritionBadge = Color(0xFFE8F3EA);
}
