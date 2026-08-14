import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart" as material;
import "package:sesori_design_catalog/src/catalog_scenarios.dart";
import "package:sesori_design_catalog/src/prego_button_catalog.dart";
import "package:sesori_design_catalog/src/prego_catalog_theme.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";

void main() {
  test("Widgetbook component exposes playground, matrix, and every curated state", () {
    final component = buildPregoSolidButtonComponent();

    expect(component.useCases, hasLength(catalogScenarios.length + 2));
    expect(component.useCases.first.name, "Playground");
    expect(component.useCases[1].name, "All curated states");
  });

  for (final scenario in catalogScenarios) {
    testWidgets("renders ${scenario.id}", (tester) async {
      final component = buildPregoSolidButtonComponent();
      final useCase = component.useCases.singleWhere((candidate) => candidate.name == scenario.name);

      await tester.pumpWidget(
        material.MaterialApp(
          theme: pregoCatalogLightTheme,
          home: material.Scaffold(body: material.Builder(builder: useCase.build)),
        ),
      );
      await tester.pump();

      expect(find.byType(PregoButtonsSolid), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
