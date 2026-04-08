import "dart:ui" as ui;

import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "sesori_page_transitions.dart";
import "sesori_theme_tokens.dart";

Brightness getSystemBrightness() => ui.PlatformDispatcher.instance.platformBrightness;

SystemUiOverlayStyle overlayStyleForBrightness({required Brightness brightness}) {
  return brightness == Brightness.light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light;
}

PageTransitionsTheme buildPageTransitionsTheme() {
  return const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: SesoriFadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    },
  );
}

DividerThemeData buildDividerTheme({required Brightness brightness}) {
  final color = brightness == Brightness.light ? const Color(0xFFD6DCE8) : const Color(0xFF2A3447);
  return DividerThemeData(color: color, thickness: 1.0);
}

FilledButtonThemeData buildFilledButtonTheme() {
  return FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SesoriThemeTokens.radiusMedium),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.2),
    ),
  );
}

OutlinedButtonThemeData buildOutlinedButtonTheme() {
  return OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SesoriThemeTokens.radiusMedium),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.2),
    ),
  );
}

TextButtonThemeData buildTextButtonTheme({required Brightness brightness}) {
  final foregroundColor = brightness == Brightness.light ? Colors.black : const Color(0xFFE8EEF9);

  return TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: foregroundColor,
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SesoriThemeTokens.radiusSmall),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.2),
    ),
  );
}

ChipThemeData buildChipTheme({required Brightness brightness}) {
  final labelColor = brightness == Brightness.light ? Colors.black : Colors.white;
  final selectedColor = brightness == Brightness.light ? SesoriThemeTokens.lightAccent : SesoriThemeTokens.darkPrimary;

  return ChipThemeData(
    labelStyle: TextStyle(
      fontFamily: SesoriThemeTokens.fontFamily,
      fontFamilyFallback: SesoriThemeTokens.fontFamilyFallback,
      fontWeight: FontWeight.w600,
      fontSize: 13,
      letterSpacing: 0.2,
      color: labelColor,
    ),
    selectedColor: selectedColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SesoriThemeTokens.radiusSmall),
    ),
  );
}

CheckboxThemeData buildCheckboxTheme({required Brightness brightness}) {
  final fillColor = brightness == Brightness.light ? Colors.black : SesoriThemeTokens.darkPrimary;
  final outlineColor = brightness == Brightness.light ? Colors.black : Colors.white;

  return CheckboxThemeData(
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
    ),
    checkColor: const WidgetStatePropertyAll(Colors.white),
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return fillColor;
      if (states.contains(WidgetState.disabled)) return outlineColor.withValues(alpha: 0.25);
      return Colors.transparent;
    }),
    side: WidgetStateBorderSide.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return BorderSide.none;
      final color = states.contains(WidgetState.disabled) ? outlineColor.withValues(alpha: 0.25) : outlineColor;
      return BorderSide(color: color);
    }),
  );
}
