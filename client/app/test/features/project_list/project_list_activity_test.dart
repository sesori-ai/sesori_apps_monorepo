import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_mobile/features/project_list/project_list_screen.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

/// Activity sits above the project list: sessions waiting on the user first,
/// then running ones, each opening its session directly.
void main() {
  const config = ServerConnectionConfig(relayHost: "relay.example.com", authToken: "test-token");
  const health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false);
  const connected = ConnectionStatus.connected(config: config, health: health);
  final project = testProjectSummary(id: "project-1", name: "My App");

  late BehaviorSubject<ConnectionStatus> statusController;
  late MockConnectionService mockConnectionService;
  late MockProjectRepository mockProjectRepository;
  late MockRegisteredBridgesService mockRegisteredBridgesService;
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
    when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async => true);
    when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => true);
    when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer((_) async => const []);
    when(() => mockProjectRepository.listProjects()).thenAnswer(
      (_) async => ApiResponse.success(Projects(data: [project])),
    );

    getIt.registerLazySingleton<ProjectRepository>(() => mockProjectRepository);
    getIt.registerLazySingleton<ConnectionService>(() => mockConnectionService);
    getIt.registerLazySingleton<SseEventTracker>(MockSseEventTracker.new);
    getIt.registerLazySingleton<RouteSource>(MockRouteSource.new);
    getIt.registerLazySingleton<SessionUnseenTracker>(FakeSessionUnseenTracker.new);
    getIt.registerLazySingleton<RegisteredBridgesService>(() => mockRegisteredBridgesService);
    getIt.registerLazySingleton<FailureReporter>(MockFailureReporter.new);
  });

  tearDown(() async {
    await overlayCubit.close();
    await statusController.close();
    await getIt.reset();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    required List<Session> sessions,
    required Map<String, SessionActivityInfo> activity,
    required void Function(String sessionId) onSessionRoute,
  }) async {
    getIt.registerFactory<RecentSessionInventoryService>(
      () => stubRecentSessionInventory(
        entries: {
          project.id: RecentSessionsLoaded(
            sourceSessions: sessions,
            visibleSessions: sessions,
            activityBySessionId: activity,
            listStateBySessionId: const {},
          ),
        },
      ),
    );
    registerListServices(projectRepository: mockProjectRepository);

    final router = GoRouter(
      routes: [
        GoRoute(path: "/", builder: (_, _) => const ProjectListScreen()),
        GoRoute(
          path: "/projects/:projectId/sessions/:sessionId",
          builder: (_, state) {
            onSessionRoute(state.pathParameters["sessionId"]!);
            return const SizedBox.shrink();
          },
        ),
      ],
    );

    await tester.pumpWidget(
      BlocProvider<ConnectionOverlayCubit>.value(
        value: overlayCubit,
        child: MaterialApp.router(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    // The running row's loader animates forever, so settle by time.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  SessionActivityInfo info({required bool awaitingInput}) => SessionActivityInfo(
    mainAgentRunning: true,
    awaitingInput: awaitingInput,
    lastUserActivityAt: null,
    updatedAt: null,
  );

  testWidgets("no session in motion leaves Activity out", (tester) async {
    await pumpScreen(
      tester,
      sessions: [testSession(id: "idle", title: "Idle")],
      activity: const {},
      onSessionRoute: (_) {},
    );

    expect(find.text("Activity"), findsNothing);
    expect(find.text("My App"), findsOneWidget);
  });

  testWidgets("waiting sessions lead, running ones follow, and a row opens its session", (tester) async {
    String? openedSessionId;
    await pumpScreen(
      tester,
      sessions: [
        testSession(id: "running", title: "Running work"),
        testSession(id: "waiting", title: "Needs an answer"),
      ],
      activity: {
        "running": info(awaitingInput: false),
        "waiting": info(awaitingInput: true),
      },
      onSessionRoute: (id) => openedSessionId = id,
    );

    expect(find.text("Activity"), findsOneWidget);
    expect(find.text("Projects"), findsWidgets);
    final waitingRow = find.byKey(const ValueKey("project-list-activity-waiting"));
    final runningRow = find.byKey(const ValueKey("project-list-activity-running"));
    expect(tester.getTopLeft(waitingRow).dy, lessThan(tester.getTopLeft(runningRow).dy));
    // "Waiting" is visual only; the dot announces it, so match plain text.
    final waitingMeta = find.byWidgetPredicate(
      (widget) => widget is Text && widget.textSpan?.toPlainText(includeSemanticsLabels: false) == "Waiting · My App",
    );
    expect(find.descendant(of: waitingRow, matching: waitingMeta), findsOneWidget);

    await tester.tap(waitingRow);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(openedSessionId, "waiting");
  });
}
