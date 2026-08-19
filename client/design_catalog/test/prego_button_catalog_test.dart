import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart" as material;
import "package:sesori_design_catalog/src/catalog_scenarios.dart";
import "package:sesori_design_catalog/src/prego_button_catalog.dart";
import "package:sesori_design_catalog/src/prego_catalog_theme.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:widgetbook/widgetbook.dart";

void main() {
  test("Widgetbook component exposes playground, matrix, and every curated state", () {
    final component = buildPregoSolidButtonComponent();

    expect(component.useCases, hasLength(catalogScenarios.length + 2));
    expect(component.useCases.first.name, "Playground");
    expect(component.useCases[1].name, "All curated states");
  });

  testWidgets("playground applies the selected leading and trailing icon glyphs", (tester) async {
    await _pumpPlayground(
      tester,
      knobs: {
        "Leading icon": "true",
        "Leading icon glyph": "Trash",
        "Trailing icon": "true",
        "Trailing icon glyph": "Add",
      },
    );

    final button = tester.widget<PregoButtonsSolid>(find.byType(PregoButtonsSolid));

    expect(button.leadingIcon, material.Icons.delete_outline);
    expect(button.trailingIcon, material.Icons.add);
  });

  testWidgets("playground uses the leading glyph selection for icon-only buttons", (tester) async {
    await _pumpPlayground(
      tester,
      knobs: {"Icon only": "true", "Leading icon": "false", "Leading icon glyph": "Arrow right"},
    );

    final button = tester.widget<PregoButtonsSolid>(find.byType(PregoButtonsSolid));

    expect(button.iconOnly, isTrue);
    expect(button.leadingIcon, material.Icons.arrow_forward);
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

Future<void> _pumpPlayground(WidgetTester tester, {required Map<String, String> knobs}) async {
  final component = buildPregoSolidButtonComponent();
  final playground = component.useCases.singleWhere((candidate) => candidate.name == "Playground");
  final state = WidgetbookState(
    root: WidgetbookRoot(children: [component]),
    queryParams: {"knobs": FieldCodec.encodeQueryGroup(knobs)},
  );
  addTearDown(state.dispose);

  await tester.pumpWidget(
    WidgetbookScope(
      state: state,
      child: material.MaterialApp(
        theme: pregoCatalogLightTheme,
        home: material.Scaffold(body: material.Builder(builder: playground.build)),
      ),
    ),
  );
  await tester.pump();
}
