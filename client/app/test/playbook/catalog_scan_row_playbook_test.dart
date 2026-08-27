import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart" as material;
import "package:sesori_mobile/core/widgets/catalog_scan_row.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:theme_prego/module_prego.dart";

import "catalog_scan_row_playbook.dart";

void main() {
  test("scenario ids and names are unique", () {
    expect(
      catalogScanRowScenarios.map((scenario) => scenario.id).toSet(),
      hasLength(catalogScanRowScenarios.length),
    );
    expect(
      catalogScanRowScenarios.map((scenario) => scenario.name).toSet(),
      hasLength(catalogScanRowScenarios.length),
    );
  });

  test("Widgetbook exposes the matrix, playground, and each curated variant", () {
    final component = buildCatalogScanRowComponent();

    expect(component.useCases, hasLength(catalogScanRowScenarios.length + 2));
    expect(component.useCases.first.name, "All states and variants");
    expect(component.useCases[1].name, "Playground");
  });

  for (final scenario in catalogScanRowScenarios) {
    testWidgets("renders ${scenario.id}", (tester) async {
      final component = buildCatalogScanRowComponent();
      final useCase = component.useCases.singleWhere((candidate) => candidate.name == scenario.name);

      await tester.pumpWidget(
        material.MaterialApp(
          theme: material.ThemeData(
            colorScheme: PregoColors.light.toFlutterColorScheme(),
            textTheme: PregoTextTheme.light.asFlutterTextTheme(),
            fontFamily: PregoTextTheme.fontFamily,
            fontFamilyFallback: PregoTextTheme.fontFamilyFallback,
            extensions: [PregoDesignSystem.light],
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: material.Scaffold(body: material.Builder(builder: useCase.build)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(CatalogScanRow), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
