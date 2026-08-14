import "package:flutter/widgets.dart";
import "package:material_ui/material_ui.dart" as material;
import "package:theme_prego/module_prego.dart";
import "package:widgetbook/widgetbook.dart";

final pregoCatalogLightTheme = _buildPregoTheme(designSystem: PregoDesignSystem.light);
final pregoCatalogDarkTheme = _buildPregoTheme(designSystem: PregoDesignSystem.dark);

material.ThemeData _buildPregoTheme({required PregoDesignSystem designSystem}) => material.ThemeData(
  colorScheme: designSystem.colors.toFlutterColorScheme(),
  scaffoldBackgroundColor: designSystem.colors.bgSurface1,
  textTheme: designSystem.textTheme.asFlutterTextTheme(),
  fontFamily: PregoTextTheme.fontFamily,
  fontFamilyFallback: PregoTextTheme.fontFamilyFallback,
  extensions: [designSystem],
);

// ignore: no_slop_linter/prefer_required_named_parameters, Widgetbook AppBuilder signature
Widget buildPregoCatalogApp(BuildContext _, Widget child) {
  return material.MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: pregoCatalogLightTheme,
    home: material.Material(color: pregoCatalogLightTheme.scaffoldBackgroundColor, child: child),
  );
}

ThemeAddon<material.ThemeData> buildPregoThemeAddon() => ThemeAddon<material.ThemeData>(
  themes: [
    WidgetbookTheme(name: "Prego light", data: pregoCatalogLightTheme),
    WidgetbookTheme(name: "Prego dark", data: pregoCatalogDarkTheme),
  ],
  themeBuilder: (context, theme, child) => material.Theme(
    data: theme,
    child: ColoredBox(color: theme.scaffoldBackgroundColor, child: child),
  ),
);
