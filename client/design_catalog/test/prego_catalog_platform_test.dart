import "package:flutter/widgets.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart" as material;
import "package:sesori_design_catalog/src/prego_catalog_platform.dart";
import "package:sesori_design_catalog/src/prego_catalog_theme.dart";
import "package:sesori_design_catalog/src/prego_catalog_viewports.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:widgetbook/widgetbook.dart";

void main() {
  testWidgets("bridges an iPhone viewport to the iOS PREGO interaction", (tester) async {
    await tester.pumpWidget(_probe(viewport: PregoCatalogViewports.iPhone16ProMax));

    expect(_tappableStateNames(tester), contains("_IosTappableState"));
    expect(_tappableStateNames(tester), isNot(contains("_WebTappableState")));
  });

  testWidgets("bridges an Android viewport to the Android PREGO interaction", (tester) async {
    await tester.pumpWidget(_probe(viewport: PregoCatalogViewports.pixel10Pro));

    expect(_tappableStateNames(tester), contains("_AndroidTappableState"));
    expect(_tappableStateNames(tester), isNot(contains("_WebTappableState")));
  });
}

Widget _probe({required ViewportData viewport}) => material.MaterialApp(
  theme: pregoCatalogDarkTheme.copyWith(
    platform: resolvePregoCatalogPlatform(
      encodedViewport: FieldCodec.encodeQueryGroup({"name": viewport.name}),
      viewports: PregoCatalogViewports.all,
      fallback: TargetPlatform.macOS,
    ),
  ),
  home: PregoButtonsSolid(
    label: "Continue",
    hierarchy: PregoButtonsSolidHierarchy.secondary,
    size: PregoButtonsSolidSize.lg,
    onPressed: () {},
  ),
);

List<String> _tappableStateNames(WidgetTester tester) => tester.allStates
    .map((state) => state.runtimeType.toString())
    .where((name) => name.contains("TappableState"))
    .toList();
