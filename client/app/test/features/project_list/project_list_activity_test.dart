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
  late MockRecentSessionInventoryService inventory;
  late SessionLaunchRepository launches;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    statusController = BehaviorSubject<ConnectionStatus>.seeded(connected);
    mockConnectionService = MockConnectionService();
    mockProjectRepository = MockProjectRepository();
    mockRegisteredBridgesService = MockRegisteredBridgesService();
    overlayCubit = StubConnectionOverlayCubit();
    launches = inMemorySessionLaunchRepository();

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
      () => inventory = stubRecentSessionInventory(
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

    final launchService = inMemorySessionLaunchService(launchRepository: launches);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ConnectionOverlayCubit>.value(value: overlayCubit),
          RepositoryProvider.value(value: launchService),
          BlocProvider(create: (_) => SessionLaunchCubit(launchService: launchService)),
        ],
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

  void launch() {
    launches.start(
      launchId: "launch-1",
      projectId: project.id,
      pluginId: "claude",
      startedAt: DateTime.now(),
      projectName: "My App",
      submission: NewSessionSubmissionSnapshot.text(
        draft: ComposerDraft.typed(text: "Fix the bug"),
        attachments: const [],
      ),
    );
    launches.releaseHandoff(launchId: "launch-1");
  }

  // The launch reaches the rows a few microtask hops later; then they animate in.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets("a launch leads Activity until it ends, opens nothing, and a search hides it", (tester) async {
    String? openedSessionId;
    await pumpScreen(
      tester,
      sessions: [testSession(id: "idle", title: "Idle")],
      activity: const {},
      onSessionRoute: (id) => openedSessionId = id,
    );
    expect(find.text("Activity"), findsNothing);

    launch();
    await settle(tester);
    final launchRow = find.byKey(const ValueKey("project-list-launch-launch-1"));
    expect(find.text("Activity"), findsOneWidget);
    expect(find.descendant(of: launchRow, matching: find.text("Fix the bug")), findsOneWidget);
    await tester.tap(launchRow);
    await tester.pump();
    expect(find.text("This session is still being created. You can open it once it's ready."), findsOneWidget);
    expect(openedSessionId, isNull);
    await tester.pump(const Duration(seconds: 5));

    // It has no title to match yet.
    await tester.enterText(find.byType(TextField), "My");
    await settle(tester);
    expect(launchRow, findsNothing);
    await tester.enterText(find.byType(TextField), "");
    await settle(tester);
    expect(launchRow, findsOneWidget);

    launches.fail(launchId: "launch-1", reason: RemoteFailureReason.networkDown);
    await settle(tester);
    expect(launchRow, findsNothing);
    expect(find.text("Activity"), findsNothing);
  });

  for (final reducedMotion in [false, true]) {
    testWidgets(
      reducedMotion
          ? "a launch's row appears at once under reduced motion"
          : "a launch's row grows in and moves the projects below it continuously",
      (tester) async {
        if (reducedMotion) {
          tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
            disableAnimations: true,
          );
          addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        }
        await pumpScreen(
          tester,
          sessions: [testSession(id: "idle", title: "Idle")],
          activity: const {},
          onSessionRoute: (_) {},
        );
        double projectTop() => tester.getTopLeft(find.text("My App")).dy;
        final before = projectTop();

        launch();
        await tester.pump();
        await tester.pump();
        final start = projectTop();
        await tester.pump(const Duration(milliseconds: 130));
        final middle = projectTop();
        await tester.pump(const Duration(milliseconds: 400));
        final end = projectTop();
        expect(end, greaterThan(before));
        if (reducedMotion) {
          expect(start, end);
        } else {
          expect(start, lessThan(middle));
          expect(middle, lessThan(end));
        }
      },
    );
  }

  testWidgets("pulling to refresh also re-reads each project's sessions", (tester) async {
    await pumpScreen(
      tester,
      sessions: [testSession(id: "idle", title: "Idle")],
      activity: const {},
      onSessionRoute: (_) {},
    );

    await tester.fling(find.byType(CustomScrollView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    verify(inventory.refresh).called(1);
    await tester.pump(const Duration(seconds: 10));
  });
}
