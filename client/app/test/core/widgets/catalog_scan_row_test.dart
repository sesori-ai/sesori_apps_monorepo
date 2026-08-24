import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/widgets/catalog_scan_row.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  late int cancelCount;
  late int dismissCount;

  setUp(() {
    cancelCount = 0;
    dismissCount = 0;
  });

  Future<void> pumpRow(WidgetTester tester, CatalogRescanState scan) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CatalogScanRow(
            scan: scan,
            onCancel: () => cancelCount++,
            onDismiss: () => dismissCount++,
          ),
        ),
      ),
    );
  }

  group("CatalogScanRow", () {
    testWidgets("renders nothing at all while idle", (tester) async {
      await pumpRow(tester, const CatalogRescanState.idle());

      expect(find.byType(PregoInlineAlertsNotifications), findsNothing);
      expect(tester.getSize(find.byType(CatalogScanRow)).height, 0);
    });

    testWidgets("reports the scan before any harness has reported progress", (tester) async {
      await pumpRow(tester, const CatalogRescanState.starting(pluginIds: {"codex"}));

      final loc = await AppLocalizations.delegate.load(const Locale("en"));
      expect(find.text(loc.catalogScanRunningTitle), findsOneWidget);
      expect(find.text(loc.catalogScanCancel), findsOneWidget);
    });

    testWidgets("names the harness being scanned and what it has seen", (tester) async {
      await pumpRow(
        tester,
        const CatalogRescanState.running(
          activePluginName: "Codex",
          sessionsSeen: 148,
          pluginIds: {"codex"},
        ),
      );

      expect(find.text("Codex — 148 sessions"), findsOneWidget);
    });

    testWidgets("cancels the scan in flight from the running row", (tester) async {
      await pumpRow(
        tester,
        const CatalogRescanState.running(activePluginName: "Codex", sessionsSeen: 1, pluginIds: {"codex"}),
      );

      final loc = await AppLocalizations.delegate.load(const Locale("en"));
      await tester.tap(find.text(loc.catalogScanCancel));

      expect(cancelCount, 1);
      expect(dismissCount, 0);
    });

    testWidgets("drops the projects clause when nothing new landed in one", (tester) async {
      await pumpRow(
        tester,
        const CatalogRescanState.succeeded(
          harnessCount: 2,
          counts: CatalogRescanCounts.delta(newProjects: 0, newSessions: 3),
        ),
      );

      expect(find.text("3 new sessions"), findsOneWidget);
    });

    testWidgets("joins both clauses when new items landed in a new project", (tester) async {
      await pumpRow(
        tester,
        const CatalogRescanState.succeeded(
          harnessCount: 2,
          counts: CatalogRescanCounts.delta(newProjects: 2, newSessions: 5),
        ),
      );

      expect(find.text("5 new sessions in 2 new projects"), findsOneWidget);
    });

    testWidgets("says nothing was new rather than reporting a zero", (tester) async {
      await pumpRow(
        tester,
        const CatalogRescanState.succeeded(
          harnessCount: 1,
          counts: CatalogRescanCounts.delta(newProjects: 0, newSessions: 0),
        ),
      );

      expect(find.text("No new sessions"), findsOneWidget);
    });

    // A harness that omitted its delta makes the whole row fall back, so the
    // wording must not imply any of the counted items is new.
    testWidgets("reports published totals as totals when no delta is available", (tester) async {
      await pumpRow(
        tester,
        const CatalogRescanState.succeeded(
          harnessCount: 2,
          counts: CatalogRescanCounts.totals(projects: 12, sessions: 148),
        ),
      );

      expect(find.text("148 sessions in 12 projects"), findsOneWidget);
      expect(find.textContaining("new"), findsNothing);
    });

    testWidgets("names how many harnesses failed out of the whole scan", (tester) async {
      await pumpRow(tester, const CatalogRescanState.partlyFailed(succeededCount: 2, failedCount: 1));

      expect(find.text("1 of 3 harnesses could not be scanned"), findsOneWidget);
    });

    // The bridge's raw error text is never lifted into client state, so the row
    // points at the log that has it.
    testWidgets("points at the bridge log when every harness failed", (tester) async {
      await pumpRow(tester, const CatalogRescanState.failed(harnessCount: 2));

      final loc = await AppLocalizations.delegate.load(const Locale("en"));
      expect(find.text(loc.catalogScanFailedTitle), findsOneWidget);
      expect(find.text(loc.catalogScanFailedDetail), findsOneWidget);
    });

    testWidgets("explains an older bridge instead of reporting a failure", (tester) async {
      await pumpRow(tester, const CatalogRescanState.unsupported());

      final loc = await AppLocalizations.delegate.load(const Locale("en"));
      expect(find.text(loc.catalogScanUnsupportedTitle), findsOneWidget);
      expect(find.text(loc.catalogScanUnsupportedDetail), findsOneWidget);
    });

    testWidgets("dismisses a finished scan without cancelling anything", (tester) async {
      await pumpRow(tester, const CatalogRescanState.failed(harnessCount: 1));

      final loc = await AppLocalizations.delegate.load(const Locale("en"));
      await tester.tap(find.text(loc.catalogScanDismiss));

      expect(dismissCount, 1);
      expect(cancelCount, 0);
    });
  });
}
