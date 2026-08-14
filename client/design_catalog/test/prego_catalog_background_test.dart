import "package:flutter/widgets.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart" as material;
import "package:sesori_design_catalog/src/prego_catalog_background.dart";
import "package:sesori_design_catalog/src/prego_catalog_theme.dart";
import "package:theme_prego/module_prego.dart";
import "package:widgetbook/widgetbook.dart";

void main() {
  test("canvas background addon exposes every curated Prego background", () {
    final addon = PregoCanvasBackgroundAddon();
    final field = addon.fields.single as ObjectDropdownField<PregoCatalogBackground>;

    expect(addon.groupName, "canvas-background");
    expect(field.values, PregoCatalogBackground.values);
    expect(field.initialValue, PregoCatalogBackground.surface1);
    expect(addon.valueFromQueryGroup(const {}), PregoCatalogBackground.surface1);
    expect(
      addon.valueFromQueryGroup(const {"background": "Brand section"}),
      PregoCatalogBackground.brandSection,
    );
  });

  test("canvas backgrounds resolve against the active light Prego palette", () {
    _expectBackgroundMappings(PregoDesignSystem.light.colors);
  });

  test("canvas backgrounds resolve against the active dark Prego palette", () {
    _expectBackgroundMappings(PregoDesignSystem.dark.colors);
  });

  testWidgets("canvas background addon paints behind the use case", (tester) async {
    const childKey = Key("use-case-child");
    final addon = PregoCanvasBackgroundAddon();
    final expectedColor = PregoDesignSystem.dark.colors.bgBrandSection;

    await tester.pumpWidget(
      material.MaterialApp(
        theme: pregoCatalogDarkTheme,
        home: material.Builder(
          builder: (context) => addon.buildUseCase(
            context,
            const SizedBox.expand(key: childKey),
            PregoCatalogBackground.brandSection,
          ),
        ),
      ),
    );

    expect(find.byKey(childKey), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == expectedColor,
      ),
      findsOneWidget,
    );
  });
}

void _expectBackgroundMappings(PregoColors colors) {
  final expected = {
    PregoCatalogBackground.surface1: colors.bgSurface1,
    PregoCatalogBackground.surface2: colors.bgSurface2,
    PregoCatalogBackground.surface3: colors.bgSurface3,
    PregoCatalogBackground.surface4: colors.bgSurface4,
    PregoCatalogBackground.surface5: colors.bgSurface5,
    PregoCatalogBackground.surface6: colors.bgSurface6,
    PregoCatalogBackground.surface7: colors.bgSurface7,
    PregoCatalogBackground.surface8: colors.bgSurface8,
    PregoCatalogBackground.brandPrimary: colors.bgBrandPrimary,
    PregoCatalogBackground.brandPrimaryAlt: colors.bgBrandPrimaryAlt,
    PregoCatalogBackground.brandSecondary: colors.bgBrandSecondary,
    PregoCatalogBackground.brandSection: colors.bgBrandSection,
    PregoCatalogBackground.brandSectionSubtle: colors.bgBrandSectionSubtle,
    PregoCatalogBackground.brandSolid: colors.bgBrandSolid,
  };

  expect(expected.keys, PregoCatalogBackground.values);
  for (final MapEntry(key: background, value: color) in expected.entries) {
    expect(background.resolve(colors), color, reason: background.label);
  }
}
