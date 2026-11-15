import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart" as material;
import "package:sesori_design_catalog/src/detent_sheet_scenario.dart";
import "package:sesori_design_catalog/src/prego_catalog_theme.dart";
import "package:sesori_design_catalog/src/prego_detent_sheet_catalog.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  testWidgets("the side chat use case opens the detent sheet over the live page", (tester) async {
    final useCase = buildPregoDetentSheetComponent().useCases.single;
    expect(useCase.name, detentSheetUseCaseName);

    await tester.pumpWidget(
      material.MaterialApp(theme: pregoCatalogLightTheme, home: material.Builder(builder: useCase.build)),
    );
    await tester.tap(find.text("Ask a side question"));
    await tester.pumpAndSettle();

    expect(find.byType(PregoSheetGrabber), findsOneWidget);
    expect(find.text("Side question"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
