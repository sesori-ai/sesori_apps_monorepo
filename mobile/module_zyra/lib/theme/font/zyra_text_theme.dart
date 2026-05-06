import "package:flutter/material.dart";

import "../../utils/guaranteed_text_theme.dart";
import "../zyra_theme.dart";

enum _ZyraTextThemeVariant {
  dark,
  light
  ;

  Color get color => switch (this) {
    .dark => ZyraColors.dark.textPrimary,
    .light => ZyraColors.light.textPrimary,
  };

  const _ZyraTextThemeVariant();
}

class ZyraTextTheme {
  static const fontFamily = "Satoshi Zyra";
  static const fontFamilyFallback = [".SF UI Text", ".SF UI Display", "Roboto", "Arial"];

  static final dark = ZyraTextTheme._(variant: .dark);
  static final light = ZyraTextTheme._(variant: .light);

  ZyraTextTheme._({required _ZyraTextThemeVariant variant})
    : display2xl = FontVariation(
        fontSize: 72,
        height: 90,
        letterSpacing: -2,
        color: variant.color,
      ),
      displayXl = FontVariation(
        fontSize: 60,
        height: 72,
        letterSpacing: -2,
        color: variant.color,
      ),
      displayLg = FontVariation(
        fontSize: 48,
        height: 60,
        letterSpacing: -2,
        color: variant.color,
      ),
      displayMd = FontVariation(
        fontSize: 36,
        height: 44,
        letterSpacing: -2,
        color: variant.color,
      ),
      displaySm = FontVariation(
        fontSize: 30,
        height: 38,
        letterSpacing: 0,
        color: variant.color,
      ),
      displayXs = FontVariation(
        fontSize: 24,
        height: 32,
        letterSpacing: 0,
        color: variant.color,
      ),
      textXl = FontVariation(
        fontSize: 20,
        height: 30,
        letterSpacing: 0,
        color: variant.color,
      ),
      textLg = FontVariation(
        fontSize: 18,
        height: 28,
        letterSpacing: 0,
        color: variant.color,
      ),
      textMd = FontVariation(
        fontSize: 16,
        height: 24,
        letterSpacing: 0,
        color: variant.color,
      ),
      textSm = FontVariation(
        fontSize: 14,
        height: 20,
        letterSpacing: 0,
        color: variant.color,
      ),
      textXs = FontVariation(
        fontSize: 12,
        height: 18,
        letterSpacing: 0,
        color: variant.color,
      );

  final FontVariation display2xl;
  final FontVariation displayXl;
  final FontVariation displayLg;
  final FontVariation displayMd;
  final FontVariation displaySm;
  final FontVariation displayXs;

  final FontVariation textXl;
  final FontVariation textLg;
  final FontVariation textMd;
  final FontVariation textSm;
  final FontVariation textXs;

  static ZyraTextTheme lerpTextThemes({required ZyraTextTheme a, required ZyraTextTheme b, required double t}) =>
      ZyraTextTheme._lerped(
        display2xl: FontVariation.lerpVariation(a: a.display2xl, b: b.display2xl, t: t),
        displayXl: FontVariation.lerpVariation(a: a.displayXl, b: b.displayXl, t: t),
        displayLg: FontVariation.lerpVariation(a: a.displayLg, b: b.displayLg, t: t),
        displayMd: FontVariation.lerpVariation(a: a.displayMd, b: b.displayMd, t: t),
        displaySm: FontVariation.lerpVariation(a: a.displaySm, b: b.displaySm, t: t),
        displayXs: FontVariation.lerpVariation(a: a.displayXs, b: b.displayXs, t: t),
        textXl: FontVariation.lerpVariation(a: a.textXl, b: b.textXl, t: t),
        textLg: FontVariation.lerpVariation(a: a.textLg, b: b.textLg, t: t),
        textMd: FontVariation.lerpVariation(a: a.textMd, b: b.textMd, t: t),
        textSm: FontVariation.lerpVariation(a: a.textSm, b: b.textSm, t: t),
        textXs: FontVariation.lerpVariation(a: a.textXs, b: b.textXs, t: t),
      );

  ZyraTextTheme._lerped({
    required this.display2xl,
    required this.displayXl,
    required this.displayLg,
    required this.displayMd,
    required this.displaySm,
    required this.displayXs,
    required this.textXl,
    required this.textLg,
    required this.textMd,
    required this.textSm,
    required this.textXs,
  });

  GuaranteedTextTheme asFlutterTextTheme() => GuaranteedTextTheme(
    displayLarge: displayLg.medium,
    displayMedium: displayMd.bold,
    displaySmall: displaySm.bold,
    headlineLarge: displaySm.bold,
    headlineMedium: displayXs.bold,
    headlineSmall: textXl.bold,
    titleLarge: textXl.bold,
    titleMedium: textMd.bold,
    titleSmall: textSm.bold,
    labelLarge: textMd.bold,
    labelMedium: textSm.bold,
    labelSmall: textXs.bold,
    bodyLarge: textSm.medium,
    bodyMedium: textSm.regular,
    bodySmall: textXs.regular,
  );
}

class FontVariation {
  FontVariation({
    required double fontSize,
    required double letterSpacing,
    required double height,
    required Color color,
  }) : light = _createStyle(
         fontSize: fontSize,
         letterSpacing: letterSpacing,
         height: height,
         color: color,
         fontWeight: .w300,
       ),
       regular = _createStyle(
         fontSize: fontSize,
         letterSpacing: letterSpacing,
         height: height,
         color: color,
         fontWeight: .w400,
       ),
       medium = _createStyle(
         fontSize: fontSize,
         letterSpacing: letterSpacing,
         height: height,
         color: color,
         fontWeight: .w500,
       ),
       bold = _createStyle(
         fontSize: fontSize,
         letterSpacing: letterSpacing,
         height: height,
         color: color,
         fontWeight: .w700,
       ),
       black = _createStyle(
         fontSize: fontSize,
         letterSpacing: letterSpacing,
         height: height,
         color: color,
         fontWeight: .w900,
       );

  FontVariation._fromStyles({
    required this.light,
    required this.regular,
    required this.medium,
    required this.bold,
    required this.black,
  });

  final TextStyle light;
  final TextStyle regular;
  final TextStyle medium;
  final TextStyle bold;
  final TextStyle black;

  static FontVariation lerpVariation({required FontVariation a, required FontVariation b, required double t}) =>
      FontVariation._fromStyles(
        light: _lerpStyleNonNull(a.light, b.light, t),
        regular: _lerpStyleNonNull(a.regular, b.regular, t),
        medium: _lerpStyleNonNull(a.medium, b.medium, t),
        bold: _lerpStyleNonNull(a.bold, b.bold, t),
        black: _lerpStyleNonNull(a.black, b.black, t),
      );

  /// Non-null [TextStyle.lerp] for interpolating between two non-null text styles.
  // ignore: no_slop_linter/avoid_bang_operator, no_slop_linter/prefer_required_named_parameters
  static TextStyle _lerpStyleNonNull(TextStyle a, TextStyle b, double t) => TextStyle.lerp(a, b, t)!;

  static TextStyle _createStyle({
    required double fontSize,
    required double letterSpacing,
    required double height,
    required Color color,
    required FontWeight fontWeight,
  }) => TextStyle(
    fontFamily: ZyraTextTheme.fontFamily,
    fontFamilyFallback: ZyraTextTheme.fontFamilyFallback,
    fontSize: fontSize,
    letterSpacing: (fontSize * letterSpacing) / 100,
    height: height / fontSize,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: fontWeight,
    color: color,
  );
}
