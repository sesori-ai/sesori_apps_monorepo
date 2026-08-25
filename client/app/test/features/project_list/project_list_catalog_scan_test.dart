import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_mobile/core/widgets/catalog_scan_row.dart";
import "package:sesori_mobile/features/project_list/project_list_screen.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

/// The project list is one of the three surfaces that host a catalog scan: it
/// starts one from the second stage of its pull and reports it in a row above
/// the list.
///
/// A live scan row spins forever, so these pump a fixed duration rather than
/// settling.
const Duration _rowSettled = Duration(milliseconds: 400);

void main() {
  const config = ServerConnectionConfig(relayHost: "relay.example.com", authToken: "test-token");
  const health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false);
  const connected = ConnectionStatus.connected(config: config, health: health);

  late BehaviorSubject<ConnectionStatus> statusController;
  late MockConnectionService mockConnectionService;
  late MockProjectRepository mockProjectRepository;
  late MockRegisteredBridgesService mockRegisteredBridgesService;
  late FakeCatalogRescanService rescanService;
  late StubConnectionOverlayCubit overlayCubit;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    statusController = BehaviorSubject<ConnectionStatus>.seeded(connected);
    mockConnectionService = MockConnectionService();
    mockProjectRepository = MockProjectRepository();
    mockRegisteredBridgesService = MockRegisteredBridgesService();
    overlayCubit = StubConnectionOverlayCubit();

    when(() => mockConnectionService.status).thenAnswer((_) => statusController.stream);
    when(() => mockConnectionService.currentStatus).thenAnswer((_) => statusController.value);
    when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => true);
    when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer((_) async => const []);
    when(() => mockProjectRepository.listProjects()).thenAnswer(
      (_) async => ApiResponse.success(Projects(data: [testProjectSummary(name: "My Project")])),
    );

    getIt.registerLazySingleton<ProjectRepository>(() => mockProjectRepository);
    registerListServices(projectRepository: mockProjectRepository);
    getIt.registerLazySingleton<ConnectionService>(() => mockConnectionService);
    getIt.registerLazySingleton<SseEventTracker>(MockSseEventTracker.new);
    getIt.registerLazySingleton<RouteSource>(MockRouteSource.new);
    getIt.registerLazySingleton<SessionUnseenTracker>(FakeSessionUnseenTracker.new);
    getIt.registerLazySingleton<RegisteredBridgesService>(() => mockRegisteredBridgesService);
    getIt.registerLazySingleton<FailureReporter>(MockFailureReporter.new);

    rescanService = getIt<CatalogRescanService>() as FakeCatalogRescanService;
  });

  tearDown(() async {
    await overlayCubit.close();
    await statusController.close();
    await getIt.reset();
  });

  Widget app() {
    return BlocProvider<ConnectionOverlayCubit>.value(
      value: overlayCubit,
      child: MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ProjectListScreen(),
      ),
    );
  }

  Future<AppLocalizations> pumpLoadedList(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    return await AppLocalizations.delegate.load(const Locale("en"));
  }

  /// Publishes [scan] and lets the list rebuild around it.
  Future<void> emitScan(WidgetTester tester, CatalogRescanState scan) async {
    rescanService.emit(scan);
    await tester.pump();
    await tester.pump(_rowSettled);
  }

  /// Keeps pulling the list down in small steps until [until] holds, so these
  /// tests describe how far the user pulls rather than how much overscroll a
  /// given drag distance happens to produce under bouncing physics.
  Future<void> pullFurtherUntil(WidgetTester tester, TestGesture gesture, bool Function() until) async {
    for (var step = 0; step < 20 && !until(); step++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      // The deep stage fires from a post-frame callback, because the refresh
      // control calls its builder from inside the sliver's layout.
      await tester.pump();
    }
  }

  testWidgets("pulling past the second threshold starts a scan across every harness", (tester) async {
    final loc = await pumpLoadedList(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.text("My Project")));

    // Past the ordinary trigger, the pull invites the deeper one …
    await pullFurtherUntil(tester, gesture, () => find.text(loc.catalogScanPullCaption).evaluate().isNotEmpty);
    expect(find.text(loc.catalogScanPullCaption), findsOneWidget);
    expect(rescanService.startAllCalls, 0, reason: "the deeper threshold has not been crossed yet");

    // … and crossing it starts the scan while the finger is still down, which
    // is why the row that reports it has to offer its own cancel.
    await pullFurtherUntil(tester, gesture, () => rescanService.startAllCalls > 0);
    expect(rescanService.startAllCalls, 1);
    expect(find.text(loc.catalogScanDeepCaption), findsOneWidget);

    // Still one scan however much further the same pull travels.
    await pullFurtherUntil(tester, gesture, () => false);
    expect(rescanService.startAllCalls, 1);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets("reports a running scan above the list without displacing it", (tester) async {
    final loc = await pumpLoadedList(tester);
    expect(find.byType(PregoInlineAlertsNotifications), findsNothing);

    await emitScan(
      tester,
      const CatalogRescanState.running(activePluginName: "Codex", sessionsSeen: 148, pluginIds: {"codex"}),
    );

    expect(find.text(loc.catalogScanRunningTitle), findsOneWidget);
    expect(find.text("Codex — 148 sessions"), findsOneWidget);
    expect(find.text("My Project"), findsOneWidget);
  });

  testWidgets("clears the row once the scan is dismissed", (tester) async {
    await pumpLoadedList(tester);

    await emitScan(tester, const CatalogRescanState.starting(pluginIds: {"codex"}));
    expect(find.byType(PregoInlineAlertsNotifications), findsOneWidget);

    await emitScan(tester, const CatalogRescanState.idle());
    expect(find.byType(PregoInlineAlertsNotifications), findsNothing);
    expect(find.text("My Project"), findsOneWidget);
  });

  testWidgets("cancels the scan from the row it is reported in", (tester) async {
    final loc = await pumpLoadedList(tester);

    await emitScan(tester, const CatalogRescanState.starting(pluginIds: {"codex"}));
    await tester.tap(find.text(loc.catalogScanCancel));

    expect(rescanService.cancelCalls, 1);
  });

  testWidgets("clears a finished scan the user has read", (tester) async {
    final loc = await pumpLoadedList(tester);

    await emitScan(
      tester,
      const CatalogRescanState.succeeded(
        harnessCount: 1,
        counts: CatalogRescanCounts.delta(newProjects: 1, newSessions: 4),
      ),
    );
    expect(find.text("4 new sessions in 1 new project"), findsOneWidget);

    await tester.tap(find.text(loc.catalogScanDismiss));
    expect(rescanService.dismissCalls, 1);
  });

  // Nothing to scan into yet, and the pull there already means "reconnect".
  testWidgets("offers no scan while the bridge is disconnected", (tester) async {
    when(() => mockProjectRepository.listProjects()).thenAnswer(
      (_) async => ApiResponse.error(ApiError.generic()),
    );
    statusController.add(const ConnectionStatus.bridgeOffline(config: config, health: health));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byType(CatalogScanRow), findsNothing);
  });
}
