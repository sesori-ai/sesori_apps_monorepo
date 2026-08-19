import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart" as material;
import "package:sesori_design_catalog/src/prego_catalog_theme.dart";
import "package:theme_prego/module_prego.dart";
import "package:widgetbook/widgetbook.dart";

void main() {
  test("catalog themes use the Prego surface background", () {
    expect(
      pregoCatalogLightTheme.scaffoldBackgroundColor,
      PregoDesignSystem.light.colors.bgSurface1,
    );
    expect(
      pregoCatalogDarkTheme.scaffoldBackgroundColor,
      PregoDesignSystem.dark.colors.bgSurface1,
    );
  });

  test("theme addon keeps existing share-link values", () {
    final addon = buildPregoThemeAddon();
    final field = addon.fields.single as Field<WidgetbookTheme<material.ThemeData>>;

    expect(field.type, FieldType.objectSegmented);
    expect(field.codec.toParam(addon.themes.first), "Prego light");
    expect(field.codec.toParam(addon.themes.last), "Prego dark");
    expect(addon.valueFromQueryGroup(const {"name": "Prego dark"}), addon.themes.last);
  });

  testWidgets("theme addon renders a compact Light and Dark segmented control", (tester) async {
    final addon = buildPregoThemeAddon();
    final field = addon.fields.single as Field<WidgetbookTheme<material.ThemeData>>;

    await tester.pumpWidget(
      material.MaterialApp(
        home: material.Scaffold(
          body: material.Builder(
            builder: (context) => material.SizedBox(
              width: 240,
              child: field.toWidget(context, addon.groupName, field.initialValue),
            ),
          ),
        ),
      ),
    );

    expect(find.text("Light"), findsOneWidget);
    expect(find.text("Dark"), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is material.SegmentedButton<WidgetbookTheme<material.ThemeData>>,
      ),
      findsOneWidget,
    );
    expect(find.byType(material.DropdownButton), findsNothing);
  });
}
