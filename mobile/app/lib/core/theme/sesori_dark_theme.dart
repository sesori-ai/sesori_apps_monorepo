import "package:flutter/material.dart";

import "sesori_color_schemes.dart";
import "sesori_text_theme.dart";
import "sesori_theme_shared.dart";
import "sesori_theme_tokens.dart";

final sesoriDarkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: darkColorScheme,
  scaffoldBackgroundColor: SesoriThemeTokens.darkScaffold,
  splashFactory: InkRipple.splashFactory,
  fontFamily: SesoriThemeTokens.fontFamily,
  fontFamilyFallback: SesoriThemeTokens.fontFamilyFallback,
  textTheme: buildSesoriTextTheme(brightness: Brightness.dark),
  pageTransitionsTheme: buildPageTransitionsTheme(),
  dividerTheme: buildDividerTheme(brightness: Brightness.dark),
  filledButtonTheme: buildFilledButtonTheme(),
  outlinedButtonTheme: buildOutlinedButtonTheme(),
  textButtonTheme: buildTextButtonTheme(brightness: Brightness.dark),
  chipTheme: buildChipTheme(brightness: Brightness.dark),
  checkboxTheme: buildCheckboxTheme(brightness: Brightness.dark),
  appBarTheme: AppBarTheme(
    backgroundColor: SesoriThemeTokens.darkScaffold,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: buildSesoriTextTheme(brightness: Brightness.dark).titleMedium,
    systemOverlayStyle: overlayStyleForBrightness(brightness: Brightness.dark),
  ),
  cardTheme: CardThemeData(
    color: darkColorScheme.surface,
    margin: EdgeInsets.zero,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SesoriThemeTokens.radiusMedium),
      side: BorderSide(color: darkColorScheme.outlineVariant),
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: darkColorScheme.primary,
    foregroundColor: darkColorScheme.onPrimary,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SesoriThemeTokens.radiusMedium),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: darkColorScheme.surfaceContainerLow,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(SesoriThemeTokens.radiusMedium),
      borderSide: BorderSide(color: darkColorScheme.outlineVariant),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(SesoriThemeTokens.radiusMedium),
      borderSide: BorderSide(color: darkColorScheme.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(SesoriThemeTokens.radiusMedium),
      borderSide: BorderSide(color: darkColorScheme.primary, width: 1.5),
    ),
  ),
  bottomSheetTheme: BottomSheetThemeData(
    backgroundColor: darkColorScheme.surface,
    modalBackgroundColor: darkColorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(SesoriThemeTokens.radiusLarge)),
    ),
  ),
  progressIndicatorTheme: ProgressIndicatorThemeData(
    color: darkColorScheme.primary,
    linearTrackColor: darkColorScheme.surfaceContainerHigh,
  ),
);
