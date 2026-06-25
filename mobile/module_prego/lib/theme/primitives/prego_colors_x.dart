import "package:flutter/material.dart";

import "prego_colors.g.dart";

/// Maps [PregoColors] semantic tokens to Flutter's [ColorScheme].
///
/// This mapping is hand-maintained and intentionally lives outside the
/// generated files — it expresses product design intent, not raw Figma data.
///
/// Usage:
/// ```dart
/// final scheme = PregoColors.dark.toFlutterColorScheme();
/// ```
extension PregoColorsX on PregoColors {
  /// Converts this [PregoColors] instance to a Flutter [ColorScheme].
  ///
  /// Uses [brightness] from this instance — call as
  /// `PregoColors.light.toFlutterColorScheme()` or `PregoColors.dark.toFlutterColorScheme()`.
  ColorScheme toFlutterColorScheme() => ColorScheme(
    brightness: brightness,
    primary: brightness == .light ? bgPrimarySolid : bgBrandSolid,
    onPrimary: fgWhite,
    primaryContainer: brightness == .light ? bgBrandPrimary : bgBrandSection,
    onPrimaryContainer: brightness == .light ? textBrandPrimary : bgBrandPrimary,
    secondary: brightness == .light ? bgBrandSolid : buttonPrimaryIconHover,
    onSecondary: brightness == .light ? fgWhite : bgBrandPrimary,
    secondaryContainer: brightness == .light ? bgBrandPrimary : bgBrandSection,
    onSecondaryContainer: brightness == .light ? textBrandPrimary : bgBrandPrimary,
    tertiary: brightness == .light ? bgSuccessSolid : fgSuccessPrimary,
    onTertiary: brightness == .light ? fgWhite : bgSuccessPrimary,
    tertiaryContainer: brightness == .light ? utilitySuccess100 : bgSuccessSecondary,
    onTertiaryContainer: brightness == .light ? textSuccessPrimary : fgSuccessPrimary,
    error: brightness == .light ? fgErrorSecondary : fgErrorPrimary,
    errorContainer: bgErrorSolid,
    onError: brightness == .light ? fgWhite : bgErrorPrimary,
    onErrorContainer: brightness == .light ? fgWhite : textErrorPrimaryHover,
    surface: bgPrimary,
    surfaceContainer: bgSecondary,
    surfaceContainerHighest: brightness == .light ? bgQuaternary : bgTertiary,
    onSurface: textPrimary,
    onSurfaceVariant: brightness == .light ? textTertiary : textSecondary,
    outline: borderPrimary,
    onInverseSurface: brightness == .light ? bgBrandPrimaryAlt : fgWhite,
    inverseSurface: brightness == .light ? bgPrimarySolid : bgBrandPrimary,
    inversePrimary: brightness == .light ? bgBrandSecondary : bgBrandSectionSubtle,
    shadow: brightness == .light ? bgPrimarySolid : bgOverlay,
    surfaceTint: bgPrimary,
  );
}
