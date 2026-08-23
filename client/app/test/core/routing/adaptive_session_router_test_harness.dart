import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/sse_event.dart";
import "package:sesori_dart_core/src/repositories/bridge_repository.dart";
import "package:sesori_dart_core/src/repositories/models/plugin_discovery_snapshot.dart";
import "package:sesori_dart_core/src/repositories/plugin_preference_repository.dart";
import "package:sesori_mobile/capabilities/voice/voice_transcription_service.dart";
import "package:sesori_mobile/core/routing/app_router.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

class MockPermissionRepository() extends Mock implements PermissionRepository;

class MockRegisteredBridgesService() extends Mock implements RegisteredBridgesService;

class MockSessionDetailLoadService() extends Mock implements SessionDetailLoadService;

class MockVoiceTranscriptionService() extends Mock implements VoiceTranscriptionService;

class MockPluginRepository() extends Mock implements PluginRepository;

class MockPluginPreferenceRepository() extends Mock implements PluginPreferenceRepository;

class AdaptiveSessionRouterTestHarness() {
  late final MockProjectRepository projectRepository;
  late final MockBridgeRepository bridgeRepository;
  late final MockRegisteredBridgesService registeredBridgesService;
  late final MockSessionRepository sessionRepository;
  late final MockConnectionService connectionService;
  late final MockSseEventTracker sseEventTracker;
  late final MockProjectViewingService projectViewingService;
  late final MockRouteSource routeSource;
  late final MockFailureReporter failureReporter;
  late final MockPermissionRepository permissionRepository;
  late final MockSessionDetailLoadService sessionDetailLoadService;
  late final MockNotificationCanceller notificationCanceller;
  late final MockVoiceTranscriptionService voiceTranscriptionService;
  late final MockPluginRepository pluginRepository;
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

    projectRepository = MockProjectRepository();
    bridgeRepository = MockBridgeRepository();
    registeredBridgesService = MockRegisteredBridgesService();
    sessionRepository = MockSessionRepository();
    connectionService = MockConnectionService();
    sseEventTracker = MockSseEventTracker();
    projectViewingService = stubbedProjectViewingService();
    routeSource = MockRouteSource(initialRoute: currentRouteDef);
    failureReporter = MockFailureReporter();
    permissionRepository = MockPermissionRepository();
    sessionDetailLoadService = MockSessionDetailLoadService();
    notificationCanceller = MockNotificationCanceller();
    voiceTranscriptionService = MockVoiceTranscriptionService();
    pluginRepository = MockPluginRepository();
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

    when(() => projectRepository.listProjects()).thenAnswer((_) async => ApiResponse.success(const Projects(data: [])));
    when(
      () => projectRepository.getProject(projectId: any(named: "projectId")),
    ).thenAnswer((invocation) async {
      final projectId = invocation.namedArguments[#projectId]! as String;
      return ApiResponse.success(
        Project(
          id: projectId,
          name: "Project One",
          path: "/$projectId",
          time: null,
          supportsDedicatedWorktrees: true,
        ),
      );
    });
    when(pluginRepository.listPlugins).thenAnswer(
      (_) async => ApiResponse.success(
        PluginDiscoverySnapshot(
          bridgeId: null,
          supportsSessionOptions: false,
          plugins: const [
            PluginMetadata(
              id: "plugin-1",
              displayName: "Plugin One",
              isDefault: true,
              state: PluginLifecycleState.ready,
              actionHint: null,
            ),
          ],
        ),
      ),
    );

    when(
      () => bridgeRepository.getRegisteredBridges(),
    ).thenAnswer((_) async => ApiResponse.success(const <BridgeSummary>[]));

    when(() => registeredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => false);
    when(() => registeredBridgesService.getRegisteredBridges()).thenAnswer((_) async => const []);

    when(
      () => projectRepository.listSessions(
        projectId: any(named: "projectId"),
        waitForPrData: any(named: "waitForPrData"),
      ),
    ).thenAnswer((invocation) async {
      final projectId = invocation.namedArguments[#projectId]! as String;
      return ApiResponse.success(SessionListResponse(items: sessionsByProject[projectId] ?? const []));
    });
    when(
      () => projectRepository.getGitContext(projectId: any(named: "projectId")),
    ).thenAnswer((invocation) async {
      final projectId = invocation.namedArguments[#projectId]! as String;
      return ApiResponse.success(
        ProjectGitContext(
          baseBranch: baseBranchByProject[projectId],
          repoSlug: null,
          repoProvider: RepoProvider.other,
        ),
      );
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
    when(() => voiceTranscriptionService.prewarmRecording()).thenAnswer((_) async {});
    when(() => authSession.authStateStream).thenAnswer((_) => authStateController.stream);
    when(() => authSession.currentState).thenAnswer((_) => authStateController.value);

    final getIt = GetIt.instance;
    getIt.registerSingleton<ProjectRepository>(projectRepository);
    getIt.registerSingleton<PluginRepository>(pluginRepository);
    final pluginPreferenceRepository = MockPluginPreferenceRepository();
    when(
      () => pluginPreferenceRepository.readPluginId(bridgeId: any(named: "bridgeId")),
    ).thenAnswer((_) async => null);
    when(
      () => pluginPreferenceRepository.writePluginId(
        bridgeId: any(named: "bridgeId"),
        pluginId: any(named: "pluginId"),
      ),
    ).thenAnswer((_) async {});
    getIt.registerSingleton<NewSessionPluginService>(
      NewSessionPluginService(
        pluginRepository: pluginRepository,
        pluginPreferenceRepository: pluginPreferenceRepository,
      ),
    );
    final productAnalyticsService = MockProductAnalyticsService();
    registerListServicesWithProductAnalytics(
      projectRepository: projectRepository,
      productAnalyticsService: productAnalyticsService,
    );
    getIt.registerSingleton<BridgeRepository>(bridgeRepository);
    getIt.registerSingleton<RegisteredBridgesService>(registeredBridgesService);
    getIt.registerSingleton<SessionRepository>(sessionRepository);
    getIt.registerSingleton<NewSessionOptionsService>(
      NewSessionOptionsService(
        sessionRepository: sessionRepository,
        defaultModelSelector: const DefaultModelSelector(),
      ),
    );
    getIt.registerSingleton<ConnectionService>(connectionService);
    getIt.registerSingleton<SseEventTracker>(sseEventTracker);
    getIt.registerSingleton<SessionUnseenTracker>(FakeSessionUnseenTracker());
    getIt.registerSingleton<SessionViewingService>(stubbedSessionViewingService());
    getIt.registerSingleton<ProjectViewingService>(projectViewingService);
    getIt.registerSingleton<LifecycleSource>(MockLifecycleSource());
    getIt.registerSingleton<RouteSource>(routeSource);
    getIt.registerSingleton<FailureReporter>(failureReporter);
    getIt.registerSingleton<PermissionRepository>(permissionRepository);
    getIt.registerSingleton<SessionDetailLoadService>(sessionDetailLoadService);
    getIt.registerSingleton<NotificationCanceller>(notificationCanceller);
    getIt.registerSingleton<VoiceTranscriptionService>(voiceTranscriptionService);
    getIt.registerSingleton<ComposerDraftRepository>(inMemoryComposerDraftRepository());
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
    return MultiBlocProvider(
      providers: [
        BlocProvider<ConnectionOverlayCubit>(create: (_) => StubConnectionOverlayCubit()),
        BlocProvider<ChatInputModeCubit>(create: (_) => StubChatInputModeCubit()),
      ],
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
    config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: null),
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
    branchName: null,
    id: id,
    pluginId: "plugin-1",
    projectID: projectId,
    directory: "/tmp/$projectId",
    parentID: null,
    title: title,
    pullRequest: null,
    time: const SessionTime(created: 1700000000000, updated: 1700000000000, archived: null),
    promptDefaults: null,
    lastUserActivityAt: null,
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
    bridgeQueuedPrompts: const [],
    projectId: projectId,
    pluginId: "opencode",
    supportsPromptAttachments: false,
    messages: const [],
    olderMessagesCursor: null,
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
    isArchived: false,
  );
}
