import "package:material_ui/material_ui.dart";

import "prego_color_primitives.g.dart";
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
  /// The fill of a selected row or tab in a pointer shell's navigation, strong
  /// enough to read against the panel in both themes.
  Color get pointerSelectionFill => brightness == .light ? PregoColorPrimitives.gray300 : const Color(0xFF2C2C2D);

  /// The edge of a pointer shell's card, composer or quiet button. Light builds these
  /// from tone, so its line only just separates white from the page.
  Color get pointerHairline => brightness == .light ? const Color(0x1C000000) : borderSecondary;

  /// A pointer shell's sidebar: neutral, as the pages beside it are, in both themes.
  Color get pointerPanelFill => brightness == .light ? bgSurface1 : bgSurface2;

  /// Small warning text that clears 4.5:1 on a pointer shell's panel in both
  /// themes.
  Color get pointerWarningText => brightness == .light ? const Color(0xFFA15C00) : textWarningPrimary;

  /// The warning fill for a pointer shell's dots and buttons: a clear amber in both
  /// themes, with dark text on it.
  Color get pointerWarningFill => brightness == .light ? const Color(0xFFD98200) : bgWarningSolid;

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
    surface: bgSurface1,
    surfaceContainer: bgSecondary,
    surfaceContainerHighest: brightness == .light ? bgQuaternary : bgTertiary,
    onSurface: textPrimary,
    onSurfaceVariant: brightness == .light ? textTertiary : textSecondary,
    outline: borderPrimary,
    onInverseSurface: brightness == .light ? bgBrandPrimaryAlt : fgWhite,
    inverseSurface: brightness == .light ? bgPrimarySolid : bgBrandPrimary,
    inversePrimary: brightness == .light ? bgBrandSecondary : bgBrandSectionSubtle,
    shadow: brightness == .light ? bgPrimarySolid : bgSurface6,
    surfaceTint: bgSurface1,
  );
}
