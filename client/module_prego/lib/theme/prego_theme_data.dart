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
    // Material defaults to the arrow over controls on desktop; Sesori shows the hand wherever a click acts.
    textButtonTheme: const TextButtonThemeData(style: _clickableStyle),
    iconButtonTheme: const IconButtonThemeData(style: _clickableStyle),
    filledButtonTheme: const FilledButtonThemeData(style: _clickableStyle),
    elevatedButtonTheme: const ElevatedButtonThemeData(style: _clickableStyle),
    outlinedButtonTheme: const OutlinedButtonThemeData(style: _clickableStyle),
    segmentedButtonTheme: const SegmentedButtonThemeData(style: _clickableStyle),
    menuButtonTheme: const MenuButtonThemeData(style: _clickableStyle),
    listTileTheme: const ListTileThemeData(mouseCursor: WidgetStateMouseCursor.clickable),
    popupMenuTheme: const PopupMenuThemeData(mouseCursor: WidgetStateMouseCursor.clickable),
    checkboxTheme: const CheckboxThemeData(mouseCursor: WidgetStateMouseCursor.clickable),
    radioTheme: const RadioThemeData(mouseCursor: WidgetStateMouseCursor.clickable),
    switchTheme: const SwitchThemeData(mouseCursor: WidgetStateMouseCursor.clickable),
  );
}

const ButtonStyle _clickableStyle = ButtonStyle(mouseCursor: WidgetStateMouseCursor.clickable);
