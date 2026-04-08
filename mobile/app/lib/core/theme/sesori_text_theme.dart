import "package:flutter/material.dart";

import "sesori_theme_tokens.dart";

const _kFontHeight = 1.35;

TextTheme buildSesoriTextTheme({required Brightness brightness}) {
  final textColor = brightness == Brightness.light ? const Color(0xFF11141B) : const Color(0xFFF2F5FA);

  TextStyle style({
    required double size,
    required FontWeight weight,
    double letterSpacing = 0.0,
  }) {
    return TextStyle(
      fontFamily: SesoriThemeTokens.fontFamily,
      fontFamilyFallback: SesoriThemeTokens.fontFamilyFallback,
      fontSize: size,
      height: _kFontHeight,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      color: textColor,
    );
  }

  return TextTheme(
    displayLarge: style(size: 42, weight: FontWeight.w500, letterSpacing: 0.2),
    displayMedium: style(size: 36, weight: FontWeight.w700, letterSpacing: 0.2),
    displaySmall: style(size: 30, weight: FontWeight.w600, letterSpacing: 0.2),
    headlineLarge: style(size: 28, weight: FontWeight.w700, letterSpacing: 0.2),
    headlineMedium: style(size: 24, weight: FontWeight.w600, letterSpacing: 0.2),
    headlineSmall: style(size: 22, weight: FontWeight.w600, letterSpacing: 0.2),
    titleLarge: style(size: 20, weight: FontWeight.w700, letterSpacing: 0.2),
    titleMedium: style(size: 16, weight: FontWeight.w700, letterSpacing: 0.2),
    titleSmall: style(size: 14, weight: FontWeight.w700, letterSpacing: 0.2),
    labelLarge: style(size: 16, weight: FontWeight.w600, letterSpacing: 0.1),
    labelMedium: style(size: 14, weight: FontWeight.w600, letterSpacing: 0.1),
    labelSmall: style(size: 12, weight: FontWeight.w600, letterSpacing: 0.1),
    bodyLarge: style(size: 14, weight: FontWeight.w500, letterSpacing: 0.25),
    bodyMedium: style(size: 13, weight: FontWeight.w400, letterSpacing: 0.2),
    bodySmall: style(size: 11, weight: FontWeight.w400, letterSpacing: 0.2),
  );
}
