// ignore_for_file: overridden_fields, no_slop_linter/avoid_bang_operator

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

class NonNullTextTheme extends TextTheme {
  final TextTheme textTheme;

  const NonNullTextTheme({required this.textTheme});

  @override
  TextTheme apply({
    String? fontFamily,
    List<String>? fontFamilyFallback,
    String? package,
    double fontSizeFactor = 1.0,
    double fontSizeDelta = 0.0,
    double letterSpacingFactor = 1.0,
    double letterSpacingDelta = 0.0,
    double wordSpacingFactor = 1.0,
    double wordSpacingDelta = 0.0,
    double heightFactor = 1.0,
    double heightDelta = 0.0,
    Color? displayColor,
    Color? bodyColor,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
  }) {
    return NonNullTextTheme(
      textTheme: textTheme.apply(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        package: package,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        letterSpacingFactor: letterSpacingFactor,
        letterSpacingDelta: letterSpacingDelta,
        wordSpacingFactor: wordSpacingFactor,
        wordSpacingDelta: wordSpacingDelta,
        heightFactor: heightFactor,
        heightDelta: heightDelta,
      ),
    );
  }

  @override
  TextStyle get bodyLarge => textTheme.bodyLarge!;

  @override
  TextStyle get bodyMedium => textTheme.bodyMedium!;

  @override
  TextStyle get bodySmall => textTheme.bodySmall!;

  @override
  TextTheme copyWith({
    TextStyle? displayLarge,
    TextStyle? displayMedium,
    TextStyle? displaySmall,
    TextStyle? headlineLarge,
    TextStyle? headlineMedium,
    TextStyle? headlineSmall,
    TextStyle? titleLarge,
    TextStyle? titleMedium,
    TextStyle? titleSmall,
    TextStyle? bodyLarge,
    TextStyle? bodyMedium,
    TextStyle? bodySmall,
    TextStyle? labelLarge,
    TextStyle? labelMedium,
    TextStyle? labelSmall,
  }) {
    return NonNullTextTheme(
      textTheme: textTheme.copyWith(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        displaySmall: displaySmall,
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        headlineSmall: headlineSmall,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        titleSmall: titleSmall,
        labelLarge: labelLarge,
        labelMedium: labelMedium,
        labelSmall: labelSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
      ),
    );
  }

  @override
  TextStyle get displayLarge => textTheme.displayLarge!;

  @override
  TextStyle get displayMedium => textTheme.displayMedium!;

  @override
  TextStyle get displaySmall => textTheme.displaySmall!;

  @override
  TextStyle get headlineLarge => textTheme.headlineLarge!;

  @override
  TextStyle get headlineMedium => textTheme.headlineMedium!;

  @override
  TextStyle get headlineSmall => textTheme.headlineSmall!;

  @override
  TextStyle get labelLarge => textTheme.labelLarge!;

  @override
  TextStyle get labelMedium => textTheme.labelMedium!;

  @override
  TextStyle get labelSmall => textTheme.labelSmall!;

  @override
  TextTheme merge(TextTheme? other) => NonNullTextTheme(
    textTheme: textTheme.merge(other),
  );

  @override
  TextStyle get titleLarge => textTheme.titleLarge!;

  @override
  TextStyle get titleMedium => textTheme.titleMedium!;

  @override
  TextStyle get titleSmall => textTheme.titleSmall!;

  @override
  DiagnosticsNode toDiagnosticsNode({String? name, DiagnosticsTreeStyle? style}) =>
      textTheme.toDiagnosticsNode(name: name, style: style);

  @override
  String toStringShort() => textTheme.toStringShort();

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) => textTheme.toString(minLevel: minLevel);
}

class GuaranteedTextTheme extends TextTheme {
  @override
  final TextStyle displayLarge;
  @override
  final TextStyle displayMedium;
  @override
  final TextStyle displaySmall;
  @override
  final TextStyle headlineLarge;
  @override
  final TextStyle headlineMedium;
  @override
  final TextStyle headlineSmall;
  @override
  final TextStyle titleLarge;
  @override
  final TextStyle titleMedium;
  @override
  final TextStyle titleSmall;
  @override
  final TextStyle labelLarge;
  @override
  final TextStyle labelMedium;
  @override
  final TextStyle labelSmall;
  @override
  final TextStyle bodyLarge;
  @override
  final TextStyle bodyMedium;
  @override
  final TextStyle bodySmall;

  const GuaranteedTextTheme({
    required this.displayLarge,
    required this.displayMedium,
    required this.displaySmall,
    required this.headlineLarge,
    required this.headlineMedium,
    required this.headlineSmall,
    required this.titleLarge,
    required this.titleMedium,
    required this.titleSmall,
    required this.labelLarge,
    required this.labelMedium,
    required this.labelSmall,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.bodySmall,
  });
}
