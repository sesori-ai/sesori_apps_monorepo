import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/capabilities/voice/voice_transcription_service.dart";
import "package:sesori_mobile/core/routing/app_router.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

class MockPermissionRepository extends Mock implements PermissionRepository {}

class MockRegisteredBridgesService extends Mock implements RegisteredBridgesService {}

class MockSessionDetailLoadService extends Mock implements SessionDetailLoadService {}

class MockVoiceTranscriptionService extends Mock implements VoiceTranscriptionService {}

class AdaptiveSessionRouterTestHarness {
  late final MockProjectService projectService;
  late final MockBridgeRepository bridgeRepository;
  late final MockRegisteredBridgesService registeredBridgesService;
  late final MockSessionRepository sessionRepository;
  late final MockConnectionService connectionService;
  late final MockSseEventTracker sseEventTracker;
  late final MockRouteSource routeSource;
  late final MockFailureReporter failureReporter;
  late final MockPermissionRepository permissionRepository;
  late final MockSessionDetailLoadService sessionDetailLoadService;
  late final MockNotificationCanceller notificationCanceller;
  late final MockVoiceTranscriptionService voiceTranscriptionService;
  late final MockAuthSession authSession;
  late final BehaviorSubject<ConnectionStatus> statusController;
  late final BehaviorSubject<AuthState> authStateController;
  late final StreamController<SesoriSessionEvent> sessionEventsController;
  late final StreamController<void> maxDurationReachedController;
  late final GoRouter router;
  late final GlobalKey<NavigatorState> rootNavigatorKey;

  Future<void> setUp({
    required String initialLocation,
    required AppRouteDef currentRouteDef,
    required Map<String, List<Session>> sessionsByProject,
    Map<String, String?> baseBranchByProject = const {},
    Map<String, List<FileDiff>> diffsBySession = const {},
    Map<String, List<Session>> childSessionsBySession = const {},
    List<RouteBase> extraRoutes = const [],
  }) async {
    await GetIt.instance.reset();

    projectService = MockProjectService();
    bridgeRepository = MockBridgeRepository();
    registeredBridgesService = MockRegisteredBridgesService();
    sessionRepository = MockSessionRepository();
    connectionService = MockConnectionService();
    sseEventTracker = MockSseEventTracker();
    routeSource = MockRouteSource(initialRoute: currentRouteDef);
    failureReporter = MockFailureReporter();
    permissionRepository = MockPermissionRepository();
    sessionDetailLoadService = MockSessionDetailLoadService();
    notificationCanceller = MockNotificationCanceller();
    voiceTranscriptionService = MockVoiceTranscriptionService();
    authSession = MockAuthSession();
    statusController = BehaviorSubject<ConnectionStatus>.seeded(_connectedStatus);
    authStateController = BehaviorSubject<AuthState>.seeded(const AuthState.unauthenticated());
    sessionEventsController = StreamController<SesoriSessionEvent>.broadcast();
    maxDurationReachedController = StreamController<void>.broadcast();
    rootNavigatorKey = GlobalKey<NavigatorState>();

    when(() => connectionService.events).thenAnswer((_) => const Stream<SseEvent>.empty());
    when(() => connectionService.status).thenAnswer((_) => statusController.stream);
    when(() => connectionService.currentStatus).thenReturn(_connectedStatus);
    when(() => connectionService.sessionEvents(any())).thenAnswer((_) => sessionEventsController.stream);

    when(() => projectService.listProjects()).thenAnswer((_) async => ApiResponse.success(const Projects(data: [])));

    when(
      () => bridgeRepository.getRegisteredBridges(),
    ).thenAnswer((_) async => ApiResponse.success(const <BridgeSummary>[]));

    when(() => registeredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => false);
    when(() => registeredBridgesService.getRegisteredBridges()).thenAnswer((_) async => const []);

    when(
      () => projectService.listSessions(
        projectId: any(named: "projectId"),
        waitForPrData: any(named: "waitForPrData"),
      ),
    ).thenAnswer((invocation) async {
      final projectId = invocation.namedArguments[#projectId]! as String;
      return ApiResponse.success(SessionListResponse(items: sessionsByProject[projectId] ?? const []));
    });
    when(
      () => projectService.getBaseBranch(projectId: any(named: "projectId")),
    ).thenAnswer((invocation) async {
      final projectId = invocation.namedArguments[#projectId]! as String;
      return ApiResponse.success(BaseBranchResponse(baseBranch: baseBranchByProject[projectId]));
    });

    when(
      () => sessionRepository.getSessionDiffs(sessionId: any(named: "sessionId")),
    ).thenAnswer((invocation) async {
      final sessionId = invocation.namedArguments[#sessionId]! as String;
      return ApiResponse.success(SessionDiffsResponse(diffs: diffsBySession[sessionId] ?? const []));
    });
    when(
      () => sessionRepository.listAgents(
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
      ),
    ).thenAnswer((_) async => ApiResponse.success(Agents(agents: [testAgentInfo()])));
    when(
      () => sessionRepository.listProviders(
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
      ),
    ).thenAnswer((_) async => ApiResponse.success(testProviderListResponse()));
    when(
      () => sessionRepository.listCommands(
        projectId: any(named: "projectId"),
        pluginId: any(named: "pluginId"),
      ),
    ).thenAnswer((_) async => ApiResponse.success(const CommandListResponse(items: [])));

    Future<SessionDetailLoadResult> loadSnapshot(Invocation invocation) async {
      final projectId = invocation.namedArguments[#projectId]! as String;
      final sessionId = invocation.namedArguments[#sessionId]! as String;
      return SessionDetailLoadResult.loaded(
        snapshot: _buildDetailSnapshot(
          projectId: projectId,
          sessionId: sessionId,
          sessionsByProject: sessionsByProject,
          childSessionsBySession: childSessionsBySession,
        ),
        isBridgeConnected: true,
      );
    }

    when(
      () => sessionDetailLoadService.load(
        sessionId: any(named: "sessionId"),
        projectId: any(named: "projectId"),
      ),
    ).thenAnswer(loadSnapshot);
    when(
      () => sessionDetailLoadService.reload(
        sessionId: any(named: "sessionId"),
        projectId: any(named: "projectId"),
      ),
    ).thenAnswer(loadSnapshot);

    when(
      () => failureReporter.recordFailure(
        error: any(named: "error"),
        stackTrace: any(named: "stackTrace"),
        uniqueIdentifier: any(named: "uniqueIdentifier"),
        fatal: any(named: "fatal"),
        reason: any(named: "reason"),
        information: any(named: "information"),
      ),
    ).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.onMaxDurationReached).thenAnswer(
      (_) => maxDurationReachedController.stream,
    );
    when(() => authSession.authStateStream).thenAnswer((_) => authStateController.stream);
    when(() => authSession.currentState).thenAnswer((_) => authStateController.value);

    final getIt = GetIt.instance;
    getIt.registerSingleton<ProjectService>(projectService);
    getIt.registerSingleton<BridgeRepository>(bridgeRepository);
    getIt.registerSingleton<RegisteredBridgesService>(registeredBridgesService);
    getIt.registerSingleton<SessionService>(SessionService(repository: sessionRepository));
    getIt.registerSingleton<SessionRepository>(sessionRepository);
    getIt.registerSingleton<ConnectionService>(connectionService);
    getIt.registerSingleton<SseEventTracker>(sseEventTracker);
    getIt.registerSingleton<SessionUnseenTracker>(FakeSessionUnseenTracker());
    getIt.registerSingleton<SessionViewingService>(stubbedSessionViewingService());
    getIt.registerSingleton<LifecycleSource>(MockLifecycleSource());
    getIt.registerSingleton<RouteSource>(routeSource);
    getIt.registerSingleton<FailureReporter>(failureReporter);
    getIt.registerSingleton<PermissionRepository>(permissionRepository);
    getIt.registerSingleton<SessionDetailLoadService>(sessionDetailLoadService);
    getIt.registerSingleton<NotificationCanceller>(notificationCanceller);
    getIt.registerSingleton<VoiceTranscriptionService>(voiceTranscriptionService);
    getIt.registerLazySingleton<DraftStore>(DraftStore.new);
    getIt.registerLazySingleton<NewSessionSelectionTracker>(NewSessionSelectionTracker.new);
    getIt.registerSingleton<AuthSession>(authSession);

    router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: initialLocation,
      routes: [
        ...extraRoutes,
        ..._buildHarnessRoutes(rootNavigatorKey: rootNavigatorKey),
      ],
    );
  }

  Widget buildApp() {
    return BlocProvider<ConnectionOverlayCubit>(
      create: (_) => StubConnectionOverlayCubit(),
      child: MaterialApp.router(
        routerConfig: router,
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
      ),
    );
  }

  String get currentLocation => router.routeInformationProvider.value.uri.toString();

  void emitSessionEvent({required SesoriSessionEvent event}) => sessionEventsController.add(event);

  Future<void> tearDown() async {
    await statusController.close();
    await authStateController.close();
    await sessionEventsController.close();
    await maxDurationReachedController.close();
    await GetIt.instance.reset();
  }

  static const ConnectionStatus _connectedStatus = ConnectionStatus.connected(
    config: ServerConnectionConfig(relayHost: "relay.example.com"),
    health: HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null),
  );
}

List<RouteBase> _buildHarnessRoutes({required GlobalKey<NavigatorState> rootNavigatorKey}) {
  return buildAppRoutesForTesting(rootNavigatorKey: rootNavigatorKey);
}

Session adaptiveTestSession({
  required String projectId,
  required String id,
  required String title,
}) {
  return Session(
    id: id,
    pluginId: "plugin-1",
    projectID: projectId,
    directory: "/tmp/$projectId",
    parentID: null,
    title: title,
    summary: const SessionSummary(files: 1),
    pullRequest: null,
    time: const SessionTime(created: 1700000000000, updated: 1700000000000, archived: null),
    promptDefaults: null,
  );
}

FileDiff adaptiveTestDiff({String file = "lib/src/example.dart"}) {
  return FileDiff.content(
    file: file,
    before: "class Example {}",
    after: "class Example { int value = 1; }",
    additions: 1,
    deletions: 0,
    status: FileDiffStatus.modified,
  );
}

SessionDetailSnapshot _buildDetailSnapshot({
  required String projectId,
  required String sessionId,
  required Map<String, List<Session>> sessionsByProject,
  required Map<String, List<Session>> childSessionsBySession,
}) {
  final matchingSession = sessionsByProject[projectId]?.firstWhere(
    (session) => session.id == sessionId,
    orElse: () => adaptiveTestSession(projectId: projectId, id: sessionId, title: "Session"),
  );

  return SessionDetailSnapshot(
    projectId: projectId,
    messages: const [],
    pendingQuestions: const [],
    pendingPermissions: const [],
    childSessions: childSessionsBySession[sessionId] ?? const [],
    statuses: {sessionId: const SessionStatus.idle()},
    agents: [testAgentInfo()],
    providerData: testProviderListResponse(),
    commands: const [],
    canonicalSessionTitle: matchingSession?.title ?? "Session",
    promptDefaults: null,
    isRootSession: true,
  );
}
