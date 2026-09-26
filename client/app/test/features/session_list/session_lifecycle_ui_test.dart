import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/session_list/session_list_cubit_provider.dart";
import "package:sesori_mobile/features/session_list/session_list_screen.dart";
import "package:sesori_shared/sesori_shared.dart" hide SessionCleanupRejection;
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

// ---------------------------------------------------------------------------
// Mock classes
// ---------------------------------------------------------------------------

class MockSessionListCubit() extends MockCubit<SessionListState> implements SessionListCubit {
  SessionCleanupRejection? _lastCleanupRejection;

  @override
  SessionCleanupRejection? get lastCleanupRejection => _lastCleanupRejection;

  @override
  String get projectId => "project-1";
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildScreenApp({required Widget child}) {
  return BlocProvider<ConnectionOverlayCubit>(
    create: (_) => StubConnectionOverlayCubit(),
    child: BlocProvider(
      create: (_) =>
          PendingSessionArchiveCubit(cleanupService: SessionCleanupService(repository: MockSessionRepository())),
      child: MaterialApp(
        theme: ThemeData(
          colorScheme: PregoColors.light.toFlutterColorScheme(),
          textTheme: PregoTextTheme.light.asFlutterTextTheme(),
          extensions: [PregoDesignSystem.light],
        ),
        darkTheme: ThemeData(
          colorScheme: PregoColors.dark.toFlutterColorScheme(),
          textTheme: PregoTextTheme.dark.asFlutterTextTheme(),
          extensions: [PregoDesignSystem.dark],
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );
}

Session _testSessionWithPullRequest() {
  return const Session(
    approvalOverride: null,
    autoContinuation: null,
    branchName: null,
    id: "session-pr-1",
    pluginId: "plugin-1",
    projectID: "project-1",
    directory: "/home/user/my-project",
    parentID: null,
    title: "PR Session",
    pullRequest: PullRequestInfo(
      number: 42,
      url: "https://github.com/sesori-ai/sesori_apps_monorepo/pull/42",
      title: "Fix status rendering",
      state: PrState.open,
      mergeableStatus: PrMergeableStatus.mergeable,
      reviewDecision: PrReviewDecision.approved,
      checkStatus: PrCheckStatus.success,
    ),
    time: SessionTime(
      created: 1700000000000,
      updated: 1700000000000,
      archived: null,
    ),
    promptDefaults: null,
    lastUserActivityAt: null,
  );
}

void main() {
  late MockSessionListCubit mockCubit;
  late MockSessionRepository mockSessionService;
  late MockProjectRepository mockProjectRepository;
  late MockConnectionService mockConnectionService;
  late MockSseEventTracker mockSseEventTracker;
  late MockRouteSource mockRouteSource;
  late MockFailureReporter mockFailureReporter;
  late BehaviorSubject<ConnectionStatus> statusController;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockCubit = MockSessionListCubit();
    mockSessionService = MockSessionRepository();
    mockProjectRepository = MockProjectRepository();
    mockConnectionService = MockConnectionService();
    mockSseEventTracker = MockSseEventTracker();
    mockRouteSource = MockRouteSource(initialRoute: AppRouteDef.sessions);
    mockFailureReporter = MockFailureReporter();
    statusController = BehaviorSubject<ConnectionStatus>.seeded(
      const ConnectionStatus.connected(
        config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: null),
        health: HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false),
      ),
    );

    when(() => mockConnectionService.events).thenAnswer((_) => const Stream<SseEvent>.empty());
    when(() => mockConnectionService.status).thenAnswer((_) => statusController.stream);
    when(() => mockConnectionService.currentStatus).thenReturn(
      const ConnectionStatus.connected(
        config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: null),
        health: HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false),
      ),
    );
    when(
      () => mockProjectRepository.getGitContext(projectId: any(named: "projectId")),
    ).thenAnswer(
      (_) async => ApiResponse.success(
        const ProjectGitContext(baseBranch: null, repoSlug: null, repoProvider: RepoProvider.other),
      ),
    );
    when(
      () => mockFailureReporter.recordFailure(
        error: any(named: "error"),
        stackTrace: any(named: "stackTrace"),
        uniqueIdentifier: any(named: "uniqueIdentifier"),
        fatal: any(named: "fatal"),
        reason: any(named: "reason"),
        information: any(named: "information"),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    await statusController.close();

    final getIt = GetIt.instance;
    if (getIt.isRegistered<ProjectRepository>()) {
      getIt.unregister<ProjectRepository>();
    }
    if (getIt.isRegistered<ConnectionService>()) {
      getIt.unregister<ConnectionService>();
    }
    if (getIt.isRegistered<SseEventTracker>()) {
      getIt.unregister<SseEventTracker>();
    }
    if (getIt.isRegistered<RouteSource>()) {
      getIt.unregister<RouteSource>();
    }
    if (getIt.isRegistered<FailureReporter>()) {
      getIt.unregister<FailureReporter>();
    }
    if (getIt.isRegistered<ProjectViewingService>()) {
      getIt.unregister<ProjectViewingService>();
    }
  });

  // ---------------------------------------------------------------------------
  // Session tile
  // ---------------------------------------------------------------------------

  group("Session tile PR rendering", () {
    testWidgets("renders the PR row when a session has pullRequest data", (tester) async {
      final getIt = GetIt.instance;
      final session = _testSessionWithPullRequest();
      final projectViewingService = stubbedProjectViewingService();

      when(
        () => mockProjectRepository.listSessions(
          projectId: session.projectID,
          waitForPrData: any(named: "waitForPrData"),
        ),
      ).thenAnswer((_) async => ApiResponse.success(SessionListResponse(items: [session])));
      getIt.registerSingleton<SessionRepository>(mockSessionService);
      getIt.registerSingleton<ProjectRepository>(mockProjectRepository);
      registerListServices(
        projectRepository: mockProjectRepository,
      );
      getIt.registerSingleton<ConnectionService>(mockConnectionService);
      getIt.registerSingleton<SseEventTracker>(mockSseEventTracker);
      getIt.registerSingleton<SessionUnseenTracker>(FakeSessionUnseenTracker());
      getIt.registerSingleton<RouteSource>(mockRouteSource);
      getIt.registerSingleton<FailureReporter>(mockFailureReporter);
      getIt.registerSingleton<ProjectViewingService>(projectViewingService);

      await tester.pumpWidget(
        _buildScreenApp(
          child: const SessionListCubitProvider(
            filter: SessionListFilter.active,
            projectId: "project-1",
            child: SessionListScreen(projectId: "project-1", projectName: null),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("PR Session"), findsOneWidget);
      expect(find.text("PR #42"), findsOneWidget);
      expect(find.text("Open"), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Session list panel
  // ---------------------------------------------------------------------------

  group("Session list panel", () {
    testWidgets("renders without an internal Scaffold", (tester) async {
      final session = testSession(title: "Panel Session");
      when(() => mockCubit.state).thenReturn(
        SessionListState.loaded(sessions: [session], baseBranch: null, repoSlug: null),
      );

      await tester.pumpWidget(
        _buildScreenApp(
          child: Material(
            child: BlocProvider<SessionListCubit>.value(
              value: mockCubit,
              child: SessionListPanel(
                onOpenArchived: mockCubit.toggleArchived,
                projectName: "Project One",
                onNewSession: () {},
                onSessionTap: ({required session}) {},
                actionDispatcher: const SessionListActionDispatcher(
                  deleteConfirmation: SessionDeleteConfirmation.sheet,
                  onSessionArchived: null,
                  onSessionDeleted: null,
                  onSessionMarkedUnread: null,
                ),
                archivedEmptyState: const SessionArchivedEmptyState(artwork: null),
                onBack: null,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Scaffold), findsNothing);
      expect(find.text("Panel Session"), findsOneWidget);
      expect(find.byIcon(TablerRegular.plus), findsOneWidget);
    });

    testWidgets("selected session is visually marked", (tester) async {
      final session = testSession(title: "Selected Session");
      when(() => mockCubit.state).thenReturn(
        SessionListState.loaded(sessions: [session], baseBranch: null, repoSlug: null),
      );

      await tester.pumpWidget(
        _buildScreenApp(
          child: Material(
            child: BlocProvider<SessionListCubit>.value(
              value: mockCubit,
              child: SessionListPanel(
                onOpenArchived: mockCubit.toggleArchived,
                projectName: "Project One",
                selectedSessionId: session.id,
                onNewSession: () {},
                onSessionTap: ({required session}) {},
                actionDispatcher: const SessionListActionDispatcher(
                  deleteConfirmation: SessionDeleteConfirmation.sheet,
                  onSessionArchived: null,
                  onSessionDeleted: null,
                  onSessionMarkedUnread: null,
                ),
                archivedEmptyState: const SessionArchivedEmptyState(artwork: null),
                onBack: null,
              ),
            ),
          ),
        ),
      );

      final tile = tester.widget<SessionTile>(find.byType(SessionTile));
      expect(tile.selected, isTrue);
    });
  });
}
