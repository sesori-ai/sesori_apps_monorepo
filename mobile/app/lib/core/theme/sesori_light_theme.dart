import "package:flutter/material.dart";

import "sesori_color_schemes.dart";
import "sesori_text_theme.dart";
import "sesori_theme_shared.dart";
import "sesori_theme_tokens.dart";

final sesoriLightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: lightColorScheme,
  scaffoldBackgroundColor: SesoriThemeTokens.lightScaffold,
  splashFactory: InkRipple.splashFactory,
  fontFamily: SesoriThemeTokens.fontFamily,
  fontFamilyFallback: SesoriThemeTokens.fontFamilyFallback,
  textTheme: buildSesoriTextTheme(brightness: Brightness.light),
  pageTransitionsTheme: buildPageTransitionsTheme(),
  dividerTheme: buildDividerTheme(brightness: Brightness.light),
  filledButtonTheme: buildFilledButtonTheme(),
  outlinedButtonTheme: buildOutlinedButtonTheme(),
  textButtonTheme: buildTextButtonTheme(brightness: Brightness.light),
  chipTheme: buildChipTheme(brightness: Brightness.light),
  checkboxTheme: buildCheckboxTheme(brightness: Brightness.light),
  appBarTheme: AppBarTheme(
    backgroundColor: SesoriThemeTokens.lightScaffold,
    foregroundColor: Colors.black,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: buildSesoriTextTheme(brightness: Brightness.light).titleMedium,
    systemOverlayStyle: overlayStyleForBrightness(brightness: Brightness.light),
  ),
  cardTheme: CardThemeData(
    color: lightColorScheme.surface,
    margin: EdgeInsets.zero,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SesoriThemeTokens.radiusMedium),
      side: BorderSide(color: lightColorScheme.outlineVariant),
    ),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    backgroundColor: lightColorScheme.primary,
    foregroundColor: lightColorScheme.onPrimary,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SesoriThemeTokens.radiusMedium),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: lightColorScheme.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(SesoriThemeTokens.radiusMedium),
      borderSide: BorderSide(color: lightColorScheme.outlineVariant),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(SesoriThemeTokens.radiusMedium),
      borderSide: BorderSide(color: lightColorScheme.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(SesoriThemeTokens.radiusMedium),
      borderSide: BorderSide(color: lightColorScheme.primary, width: 1.5),
    ),
  ),
  bottomSheetTheme: BottomSheetThemeData(
    backgroundColor: lightColorScheme.surface,
    modalBackgroundColor: lightColorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(SesoriThemeTokens.radiusLarge)),
    ),
  ),
  progressIndicatorTheme: ProgressIndicatorThemeData(
    color: lightColorScheme.primary,
    linearTrackColor: lightColorScheme.surfaceContainerHigh,
  ),
);
