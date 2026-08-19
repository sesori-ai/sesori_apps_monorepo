import "package:flutter/widgets.dart";
import "package:material_ui/material_ui.dart" as material;
import "package:theme_prego/module_prego.dart";
import "package:widgetbook/widgetbook.dart";

const _lightThemeName = "Prego light";
const _darkThemeName = "Prego dark";

final pregoCatalogLightTheme = _buildPregoTheme(designSystem: PregoDesignSystem.light);
final pregoCatalogDarkTheme = _buildPregoTheme(designSystem: PregoDesignSystem.dark);
final _pregoCatalogThemes = List<WidgetbookTheme<material.ThemeData>>.unmodifiable([
  WidgetbookTheme(name: _lightThemeName, data: pregoCatalogLightTheme),
  WidgetbookTheme(name: _darkThemeName, data: pregoCatalogDarkTheme),
]);

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

ThemeAddon<material.ThemeData> buildPregoThemeAddon() => _PregoCatalogThemeAddon();

final class _PregoCatalogThemeAddon() extends ThemeAddon<material.ThemeData> {
  this
    : super(
        themes: _pregoCatalogThemes,
        themeBuilder: (context, theme, child) => material.Theme(
          data: theme,
          child: ColoredBox(color: theme.scaffoldBackgroundColor, child: child),
        ),
      );

  @override
  List<Field<WidgetbookTheme<material.ThemeData>>> get fields => [
    _PregoThemeSegmentedField(
      name: "name",
      themes: themes,
      initialValue: initialTheme ?? themes.first,
    ),
  ];
}

final class _PregoThemeSegmentedField({
  required super.name,
  required final List<WidgetbookTheme<material.ThemeData>> themes,
  required super.initialValue,
}) extends Field<WidgetbookTheme<material.ThemeData>> {
  this
    : super(
        defaultValue: themes.first,
        type: FieldType.objectSegmented,
        codec: FieldCodec(
          toParam: (theme) => theme.name,
          toValue: (param) => switch (param) {
            _lightThemeName => themes.first,
            _darkThemeName => themes.last,
            _ => null,
          },
        ),
      );

  @override
  Widget toWidget(
    BuildContext context,
    String group,
    WidgetbookTheme<material.ThemeData>? value,
  ) {
    return material.SegmentedButton<WidgetbookTheme<material.ThemeData>>(
      expandedInsets: EdgeInsets.zero,
      showSelectedIcon: false,
      selected: {value ?? initialValue ?? themes.first},
      onSelectionChanged: (selection) => updateField(context, group, selection.single),
      segments: themes
          .map(
            (theme) => material.ButtonSegment(
              value: theme,
              label: material.Text(switch (theme.name) {
                _lightThemeName => "Light",
                _darkThemeName => "Dark",
                _ => theme.name,
              }),
            ),
          )
          .toList(),
    );
  }
}
