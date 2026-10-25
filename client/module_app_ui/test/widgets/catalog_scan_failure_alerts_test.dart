import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

class _MockRefreshService() extends Mock implements SessionListRefreshService;

void main() {
  late BehaviorSubject<CatalogRescanState> scans;

  Future<void> pumpAlerts(WidgetTester tester) async {
    scans = BehaviorSubject.seeded(const CatalogRescanState.idle());
    addTearDown(scans.close);
    final service = _MockRefreshService();
    when(() => service.scan).thenAnswer((_) => scans);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider(
          create: (_) => SessionListRefreshCubit(service: service),
          child: const CatalogScanFailureAlerts(navigatorKey: null, child: Scaffold()),
        ),
      ),
    );
  }

  Future<void> emit(WidgetTester tester, CatalogRescanState scan) async {
    scans.add(scan);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets("a failed import names its harness once", (tester) async {
    await pumpAlerts(tester);

    await emit(tester, const CatalogRescanState.failed(failedPluginIds: {"codex"}));

    expect(find.text("Couldn't import from Codex"), findsOneWidget);
  });

  testWidgets("a partly failed import names every harness that failed", (tester) async {
    await pumpAlerts(tester);

    await emit(
      tester,
      const CatalogRescanState.partlyFailed(succeededCount: 1, failedPluginIds: {"codex", "claude"}),
    );

    expect(find.text("Couldn't import from 2 harnesses: Codex, Claude Code"), findsOneWidget);
  });

  testWidgets("progress, success and an unsupported bridge raise no alert", (tester) async {
    await pumpAlerts(tester);

    await emit(
      tester,
      const CatalogRescanState.starting(activePluginName: "Codex", finishedHarnessCount: 0, pluginIds: {"codex"}),
    );
    await emit(
      tester,
      const CatalogRescanState.succeeded(
        harnessCount: 1,
        counts: CatalogRescanCounts.delta(newProjects: 0, newSessions: 2),
      ),
    );
    await emit(tester, const CatalogRescanState.unsupported());

    expect(find.textContaining("Couldn't import"), findsNothing);
  });
}
