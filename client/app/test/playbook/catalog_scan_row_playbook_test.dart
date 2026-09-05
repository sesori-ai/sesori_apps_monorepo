import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart" as material;
import "package:sesori_app_ui/sesori_app_ui.dart";
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

  test("Widgetbook exposes the action example, matrix, state picker, and each curated variant", () {
    final component = buildCatalogScanRowComponent();

    expect(component.useCases, hasLength(catalogScanRowScenarios.length + 3));
    expect(
      component.useCases.take(3).map((useCase) => useCase.name),
      ["In action · Pull to scan", "All states and variants", "State picker"],
    );
  });

  test("the action example offers the gesture demo and every curated static state", () {
    expect(catalogScanDemoSelections, hasLength(catalogScanRowScenarios.length + 1));
    expect(catalogScanDemoSelections.first, isA<CatalogScanGestureDemo>());
    expect(
      catalogScanDemoSelections.skip(1).whereType<CatalogScanStaticPreview>().map((selection) => selection.scenario),
      catalogScanRowScenarios,
    );
  });

  testWidgets("a deep pull starts and progresses the example scan", (tester) async {
    await tester.pumpWidget(_exampleHarness(const CatalogScanGestureDemo()));

    expect(find.text("Projects"), findsOneWidget);
    expect(find.text("MacBook-Pro"), findsOneWidget);
    expect(find.text("Landing"), findsOneWidget);
    expect(find.text("Scanning all harnesses"), findsNothing);

    final gesture = await tester.startGesture(const Offset(200, 320));
    var sawInvitation = false;
    var handedOffToScan = false;
    for (var step = 0; step < 16 && !handedOffToScan; step++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      final invitationVisible = find.text("Keep pulling to find new sessions").evaluate().isNotEmpty;
      if (invitationVisible) {
        sawInvitation = true;
      } else if (sawInvitation) {
        handedOffToScan = true;
      }
    }

    expect(sawInvitation, isTrue);
    expect(handedOffToScan, isTrue);

    await gesture.up();
    await tester.pump();
    expect(find.text("Starting…", skipOffstage: false), findsOneWidget);
    expect(find.text("Scanning all harnesses", skipOffstage: false), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 650));
    expect(find.text("Codex — 0 sessions"), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 750));
    expect(find.text("Codex — 3 sessions"), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text("OpenCode — 8 sessions"), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text("Scan complete"), findsOneWidget);
    expect(find.text("5 new sessions in 2 new projects"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("a static selection freezes the action example in the chosen state", (tester) async {
    final failed = catalogScanRowScenarios.singleWhere((scenario) => scenario.id == "failed");

    await tester.pumpWidget(_exampleHarness(CatalogScanStaticPreview(scenario: failed)));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text("Projects"), findsOneWidget);
    expect(find.text("MacBook-Pro"), findsOneWidget);
    expect(find.text("Scan failed"), findsOneWidget);
    expect(find.text("Check bridge logs"), findsOneWidget);
    expect(find.text("Landing"), findsOneWidget);
    expect(tester.takeException(), isNull);
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

material.Widget _exampleHarness(CatalogScanDemoSelection selection) {
  return material.MaterialApp(
    theme: material.ThemeData(
      colorScheme: PregoColors.light.toFlutterColorScheme(),
      textTheme: PregoTextTheme.light.asFlutterTextTheme(),
      fontFamily: PregoTextTheme.fontFamily,
      fontFamilyFallback: PregoTextTheme.fontFamilyFallback,
      extensions: [PregoDesignSystem.light],
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: material.Scaffold(body: CatalogScanRowInActionExample(selection: selection)),
  );
}
