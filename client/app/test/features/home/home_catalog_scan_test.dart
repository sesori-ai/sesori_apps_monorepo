import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

/// The home is one of the surfaces that host a catalog scan: every pull
/// imports, and the scan reports in a row above the list.
///
/// A live scan row spins forever, so these pump a fixed duration rather than
/// settling.
const Duration _rowSettled = Duration(milliseconds: 400);

void main() {
  const config = ServerConnectionConfig(relayHost: "relay.example.com", authToken: "test-token", bridgeId: null);
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
    when(() => mockConnectionService.events).thenAnswer((_) => const Stream.empty());
    when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => true);
    when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer((_) async => const []);
    when(() => mockProjectRepository.listProjects()).thenAnswer(
      (_) async => ApiResponse.success(Projects(data: [testProjectSummary(name: "My Project")])),
    );

    getIt.registerLazySingleton<ProjectRepository>(() => mockProjectRepository);
    // A row under the project, which names it.
    when(() => mockProjectRepository.listSessions(projectId: "project-1")).thenAnswer(
      (_) async => ApiResponse.success(SessionListResponse(items: [testSession(title: "Fix the parser")])),
    );
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
    return MultiBlocProvider(
      providers: [
        BlocProvider<ConnectionOverlayCubit>.value(value: overlayCubit),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: testHome(),
      ),
    );
  }

  Future<AppLocalizations> pumpLoadedList(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    return await AppLocalizations.delegate.load(const Locale("en"));
  }

  /// Publishes [scan] and runs the row's reveal to completion.
  ///
  /// Three frames, not two: the first rebuilds the list around the new state,
  /// the second is the reveal's first tick — which only establishes its start
  /// time — and the third carries it to the end.
  Future<void> emitScan(WidgetTester tester, CatalogRescanState scan) async {
    rescanService.emit(scan);
    await tester.pump();
    await tester.pump();
    await tester.pump(_rowSettled);
  }

  testWidgets("confirms an ordinary pull", (tester) async {
    final loc = await pumpLoadedList(tester);

    // The refresh starts on release now, so this settles the whole gesture
    // rather than pumping a fixed window from the moment of the drag.
    await tester.drag(find.text("My Project"), const Offset(0, 120));
    await tester.pumpAndSettle();

    expect(find.text(loc.sessionListRefreshSuccess), findsOneWidget);
    expect(rescanService.startAllCalls, 1, reason: "every pull imports");
  });

  // The pull has one stage: however far it travels, it is one ordinary refresh.
  testWidgets("a long pull is still one ordinary refresh", (tester) async {
    final loc = await pumpLoadedList(tester);

    await tester.drag(find.text("My Project"), const Offset(0, 600));
    await tester.pumpAndSettle();

    expect(find.text(loc.sessionListRefreshSuccess), findsOneWidget);
    expect(rescanService.startAllCalls, 1);
  });

  testWidgets("reports a running scan above the list without displacing it", (tester) async {
    final loc = await pumpLoadedList(tester);
    expect(find.text(loc.catalogScanRunningTitle(0, 1)), findsNothing);

    await emitScan(
      tester,
      const CatalogRescanState.reading(
        activePluginName: "Codex",
        sessionsSeen: 148,
        finishedHarnessCount: 0,
        pluginIds: {"codex"},
      ),
    );

    expect(find.text(loc.catalogScanRunningTitle(0, 1)), findsOneWidget);
    expect(find.text("Codex — 148 sessions found"), findsOneWidget);
    expect(find.text("My Project"), findsOneWidget);
  });

  // A scan already running when the home opens is no news: the row stands
  // with the loading skeleton, so the projects arriving move nothing.
  testWidgets("a load that starts mid-scan shows the row from its first frame and keeps the list still", (
    tester,
  ) async {
    final projectsArrive = Completer<ApiResponse<Projects>>();
    when(() => mockProjectRepository.listProjects()).thenAnswer((_) => projectsArrive.future);
    rescanService.emit(
      const CatalogRescanState.reading(
        activePluginName: "Codex",
        sessionsSeen: 12,
        finishedHarnessCount: 0,
        pluginIds: {"codex"},
      ),
    );
    final loc = await AppLocalizations.delegate.load(const Locale("en"));

    await tester.pumpWidget(app());
    expect(find.text(loc.catalogScanRunningTitle(0, 1)), findsOneWidget);
    await tester.pump(_rowSettled);
    final search = find.byType(EditableText);
    final searchTop = tester.getTopLeft(search).dy;

    projectsArrive.complete(ApiResponse.success(Projects(data: [testProjectSummary(name: "My Project")])));
    await tester.pump();
    await tester.pump(_rowSettled);

    expect(find.text("Fix the parser"), findsOneWidget);
    expect(tester.getTopLeft(search).dy, searchTop);
  });

  testWidgets("folds the row away once the scan clears itself", (tester) async {
    await pumpLoadedList(tester);

    final loc = await AppLocalizations.delegate.load(const Locale("en"));
    await emitScan(
      tester,
      const CatalogRescanState.preparingOne(
        pendingPluginName: "Codex",
        finishedHarnessCount: 0,
        pluginIds: {"codex"},
      ),
    );
    expect(find.text(loc.catalogScanRunningTitle(0, 1)), findsOneWidget);

    await emitScan(tester, const CatalogRescanState.idle());
    expect(find.text(loc.catalogScanRunningTitle(0, 1)), findsNothing);
    expect(find.text("My Project"), findsOneWidget);
  });

  testWidgets("reports a finished scan with no control to press", (tester) async {
    await pumpLoadedList(tester);

    await emitScan(
      tester,
      const CatalogRescanState.succeeded(
        harnessCount: 1,
        counts: CatalogRescanCounts.delta(newProjects: 1, newSessions: 4),
      ),
    );
    expect(find.text("4 new sessions in 1 new project"), findsOneWidget);
    expect(find.text("Dismiss"), findsNothing, reason: "the service clears a settled scan by itself");
  });

  // Nothing to scan into yet, and the pull there already means "reconnect".
  testWidgets("shows no scan row while the bridge is disconnected", (tester) async {
    when(() => mockProjectRepository.listProjects()).thenAnswer(
      (_) async => ApiResponse.error(ApiError.generic()),
    );
    statusController.add(const ConnectionStatus.bridgeOffline(config: config, health: health));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byType(CatalogScanRow), findsNothing);
  });
}
