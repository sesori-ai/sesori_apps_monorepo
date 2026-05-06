import "package:flutter/material.dart";

import "zyra_colors.g.dart";

/// Maps [ZyraColors] semantic tokens to Flutter's [ColorScheme].
///
/// This mapping is hand-maintained and intentionally lives outside the
/// generated files — it expresses product design intent, not raw Figma data.
///
/// Usage:
/// ```dart
/// final scheme = ZyraColors.dark.toFlutterColorScheme();
/// ```
extension ZyraColorsX on ZyraColors {
  /// Converts this [ZyraColors] instance to a Flutter [ColorScheme].
  ///
  /// Uses [brightness] from this instance — call as
  /// `ZyraColors.light.toFlutterColorScheme()` or `ZyraColors.dark.toFlutterColorScheme()`.
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
    surfaceContainer: brightness == .light ? bgSecondary : bgPrimaryAlt,
    surfaceContainerHighest: brightness == .light ? bgQuaternary : bgTertiary,
    onSurface: textPrimary,
    onSurfaceVariant: brightness == .light ? textTertiary : textSecondary,
    outline: borderPrimary,
    onInverseSurface: brightness == .light ? bgBrandPrimaryAlt : bgBrandPrimary,
    inverseSurface: brightness == .light ? bgPrimarySolid : bgBrandPrimary,
    inversePrimary: brightness == .light ? bgBrandSecondary : bgBrandSectionSubtle,
    shadow: brightness == .light ? bgPrimarySolid : bgOverlay,
    surfaceTint: bgPrimary,
  );
}
