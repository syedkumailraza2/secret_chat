import 'package:flutter/painting.dart';

/// Typography tokens from the Tailwind `fontSize` config (1rem = 16px).
/// Colors are intentionally unset; apply with `.copyWith(color: ...)`.
///
/// The bundled fonts are variable fonts, so each style sets both
/// `fontWeight` and the matching `wght` axis.
class AppText {
  AppText._();

  static const serif = 'EB Garamond';
  static const sans = 'Manrope';

  static TextStyle _style(
    String family,
    double size,
    double lineHeight,
    double letterSpacingEm,
    int weight,
  ) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      height: lineHeight / size,
      letterSpacing: letterSpacingEm * size,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: [FontVariation('wght', weight.toDouble())],
    );
  }

  static final displayHero = _style(serif, 72, 76, -0.02, 400);
  static final displayHeroMobile = _style(serif, 56, 60, -0.02, 400);
  static final headlineLg = _style(serif, 40, 46, -0.015, 400);
  static final headlineLgMobile = _style(serif, 32, 38, -0.01, 400);
  static final headlineMd = _style(serif, 28, 34, 0, 500);
  static final headlineSm = _style(serif, 22, 28, 0, 500);

  static final bodyLg = _style(sans, 18, 28, -0.01, 400);
  static final bodyMd = _style(sans, 15, 24, -0.005, 400);
  static final bodySm = _style(sans, 13, 20, 0, 400);

  static final labelLg = _style(sans, 14, 18, 0.02, 600);
  static final labelMd = _style(sans, 12, 16, 0.06, 600);
  static final labelSm = _style(sans, 11, 14, 0.08, 500);
}

/// Change weight on a variable-font style, keeping the `wght` axis in sync.
extension TextStyleWeight on TextStyle {
  TextStyle weight(int w) => copyWith(
        fontWeight: FontWeight.values[(w ~/ 100) - 1],
        fontVariations: [FontVariation('wght', w.toDouble())],
      );
}
