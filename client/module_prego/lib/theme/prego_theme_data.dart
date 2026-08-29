import "package:flutter/services.dart";
import "package:material_ui/material_ui.dart";

import "font/prego_text_theme.dart";
import "prego_design_system.dart";
import "primitives/prego_colors_x.dart";

/// Builds the complete Material theme owned by the Prego design system.
ThemeData buildPregoThemeData({required Brightness brightness}) {
  final PregoDesignSystem designSystem = switch (brightness) {
    Brightness.light => PregoDesignSystem.light,
    Brightness.dark => PregoDesignSystem.dark,
  };
  return ThemeData(
    colorScheme: designSystem.colors.toFlutterColorScheme(),
    textTheme: designSystem.textTheme.asFlutterTextTheme(),
    fontFamily: PregoTextTheme.fontFamily,
    fontFamilyFallback: PregoTextTheme.fontFamilyFallback,
    scaffoldBackgroundColor: designSystem.colors.bgSurface1,
    extensions: <PregoDesignSystem>[designSystem],
    appBarTheme: AppBarTheme(
      systemOverlayStyle: brightness == Brightness.light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
    ),
  );
}
