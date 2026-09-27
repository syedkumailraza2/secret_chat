import 'package:flutter/material.dart';

/// Spacing, radius and elevation tokens from the Tailwind config.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// `gutter-mobile` in the config.
  static const double gutter = 16;

  /// `margin-mobile` — the standard horizontal page padding.
  static const double margin = 20;
}

class AppRadius {
  AppRadius._();

  /// Tailwind `rounded-DEFAULT` (1rem).
  static const double normal = 16;

  /// Tailwind `rounded-lg` (2rem).
  static const double lg = 32;

  /// Tailwind `rounded-xl` (3rem).
  static const double xl = 48;

  static const double full = 9999;

  /// The 12px radius used on the primary CTAs in onboarding1/2/5.
  static const double button = 12;

  /// The 24px radius used on the profile bento cards and some nav bars.
  static const double card = 24;
}

/// The green-tinted shadows the HTML reuses across screens.
class AppShadows {
  AppShadows._();

  /// `soft-shadow` / `elevation-1` — 0 4px 12px rgba(37,100,65,0.06)
  static const soft = [
    BoxShadow(
      color: Color(0x0F256441),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  /// `elevation-2` — 0 8px 24px rgba(37,100,65,0.08)
  static const raised = [
    BoxShadow(
      color: Color(0x14256441),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  /// `active-shadow` — 0 12px 24px rgba(37,100,65,0.12)
  static const active = [
    BoxShadow(
      color: Color(0x1F256441),
      blurRadius: 24,
      offset: Offset(0, 12),
    ),
  ];

  /// The heavier CTA shadow — 0 12px 24px rgba(63,125,88,0.2)
  static const cta = [
    BoxShadow(
      color: Color(0x333F7D58),
      blurRadius: 24,
      offset: Offset(0, 12),
    ),
  ];

  /// Bottom nav — 0 -4px 12px rgba(43,106,71,0.06)
  static const bottomNav = [
    BoxShadow(
      color: Color(0x0F2B6A47),
      blurRadius: 12,
      offset: Offset(0, -4),
    ),
  ];

  /// The subtle card shadow used on the home feed cards.
  static const card = [
    BoxShadow(
      color: Color(0x0F2B6A47),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];
}

/// The single breakpoint the HTML uses (Tailwind `md:` = 768px).
class AppBreakpoints {
  AppBreakpoints._();

  static const double md = 768;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= md;
}
