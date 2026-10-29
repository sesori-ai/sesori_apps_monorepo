import "package:bloc_test/bloc_test.dart";
import "package:firebase_analytics/firebase_analytics.dart";
import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_svg/flutter_svg.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:http/http.dart" as http;
import "package:material_ui/material_ui.dart"
    show CustomScrollView, MaterialApp, Scaffold, SizedBox, SliverToBoxAdapter, ThemeData, Widget;
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart"
    show AllSessionsList, AppLocalizations, SessionListActionDispatcher, SessionScope;
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/repositories/models/analytics_delivery_result.dart";
import "package:sesori_dart_core/testing.dart";

import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_mobile/features/home/home_screen.dart";
import "package:sesori_shared/sesori_shared.dart"
    show FailureReporter, ProjectSummary, Session, SessionPageCounts, SessionPageRequest;
import "package:theme_prego/module_prego.dart" show PregoDesignSystem;
export "package:sesori_dart_core/testing.dart";

// ---------------------------------------------------------------------------
// Mock classes
// ---------------------------------------------------------------------------

/// A fixed-state [ConnectionOverlayCubit] stand-in for widget tests.
///
/// Screens read the cubit through `ConnectionBanner.maybeFor` to decide
/// whether the top-nav connection banner shows, so any harness that pumps a
/// screen must provide one. Defaults to a connected [ConnectionOverlayHidden]
/// (no banner, chain up); pass e.g. `ConnectionOverlayState.bridgeOffline()`
/// to exercise the banner.
class StubConnectionOverlayCubit({
  ConnectionOverlayState initialState = const ConnectionOverlayState.hidden(connected: true),
}) extends Cubit<ConnectionOverlayState> implements ConnectionOverlayCubit {
  this : super(initialState);

  @override
  void reconnect() {}
}

/// The composer resolves its resting layout (hold-to-talk vs tap-to-type)
/// from [ChatInputModeCubit], so any harness that pumps a composer-bearing
/// screen must provide one. Defaults to the app default, voice-first.
class StubChatInputModeCubit({ChatInputMode initialState = ChatInputMode.voiceFirst})
    extends Cubit<ChatInputMode>
    implements ChatInputModeCubit {
  this : super(initialState);

  @override
  Future<void> select({required ChatInputMode mode}) async => emit(mode);
}

/// The session page's Changes button reads its line totals from
/// [DiffSummaryCubit], so any harness that pumps that button must provide one.
class StubDiffSummaryCubit({DiffSummaryState initialState = const DiffSummaryState.unknown()})
    extends Cubit<DiffSummaryState>
    implements DiffSummaryCubit {
  this : super(initialState);

  @override
  String get sessionId => "session-1";

  @override
  Duration get refreshInterval => Duration.zero;
}

void stubProductAnalyticsService({required MockProductAnalyticsService service}) {
  final states = BehaviorSubject<ProductAnalyticsState>.seeded(ProductAnalyticsState.initial);
  addTearDown(states.close);
  when(
    () => service.logEvent(
      event: any(named: "event"),
      occurredAtUtc: any(named: "occurredAtUtc"),
    ),
  ).thenAnswer((_) async => AnalyticsDeliveryResult.acceptedBySdk);
  when(() => service.state).thenAnswer((_) => states.value);
  when(() => service.stateStream).thenAnswer((_) => states.stream);
}

void registerListServices({
  required MockProjectRepository projectRepository,
}) {
  _registerListServices(projectRepository: projectRepository, productAnalyticsService: null);
}

void registerListServicesWithProductAnalytics({
  required MockProjectRepository projectRepository,
  required MockProductAnalyticsService productAnalyticsService,
}) {
  _registerListServices(
    projectRepository: projectRepository,
    productAnalyticsService: productAnalyticsService,
  );
}

void _registerListServices({
  required MockProjectRepository projectRepository,
  required MockProductAnalyticsService? productAnalyticsService,
}) {
  if (getIt.isRegistered<ProjectListService>()) {
    getIt.unregister<ProjectListService>();
  }
  if (getIt.isRegistered<SessionListService>()) {
    getIt.unregister<SessionListService>();
  }
  if (getIt.isRegistered<ProductAnalyticsService>()) {
    getIt.unregister<ProductAnalyticsService>();
  }
  final analyticsService = productAnalyticsService ?? MockProductAnalyticsService();
  stubProductAnalyticsService(service: analyticsService);
  getIt.registerSingleton<ProjectListService>(
    ProjectListService(
      repository: projectRepository,
    ),
  );
  getIt.registerSingleton<SessionListService>(
    SessionListService(),
  );
  getIt.registerSingleton<ProductAnalyticsService>(analyticsService);
  if (getIt.isRegistered<SessionCleanupService>()) {
    getIt.unregister<SessionCleanupService>();
  }
  // Lazy: callers register their SessionRepository after the list services.
  getIt.registerFactory<SessionCleanupService>(() => SessionCleanupService(repository: getIt<SessionRepository>()));
  // The session cubits count good interactions toward the rating sheet.
  if (getIt.isRegistered<FeedbackPromptService>()) {
    getIt.unregister<FeedbackPromptService>();
  }
  getIt.registerSingleton<FeedbackPromptService>(FakeFeedbackPromptService());
  // The list cubits project the catalog scan onto their state, so every test
  // that renders a list needs one. Registered here rather than per test file
  // because it is a dependency of the lists themselves, not of any one screen.
  if (getIt.isRegistered<CatalogRescanService>()) {
    getIt.unregister<CatalogRescanService>();
  }
  getIt.registerSingleton<CatalogRescanService>(FakeCatalogRescanService());
  if (getIt.isRegistered<SelectedComputerService>()) {
    getIt.unregister<SelectedComputerService>();
  }
  getIt.registerSingleton<SelectedComputerService>(FakeSelectedComputerService());
  if (getIt.isRegistered<ActiveBridgeLocality>()) {
    getIt.unregister<ActiveBridgeLocality>();
  }
  getIt.registerSingleton<ActiveBridgeLocality>(const FakeActiveBridgeLocality());
  if (getIt.isRegistered<ProjectInventoryService>()) {
    getIt.unregister<ProjectInventoryService>();
  }
  getIt.registerFactory<ProjectInventoryService>(
    () => ProjectInventoryService(
      projectRepository: getIt<ProjectRepository>(),
      connectionService: getIt<ConnectionService>(),
      sseEventTracker: getIt<SseEventTracker>(),
      routeSource: getIt<RouteSource>(),
      projectListService: getIt<ProjectListService>(),
      sessionUnseenTracker: getIt<SessionUnseenTracker>(),
      registeredBridgesService: getIt<RegisteredBridgesService>(),
      productAnalyticsService: getIt<ProductAnalyticsService>(),
      failureReporter: getIt<FailureReporter>(),
      catalogRescanService: getIt<CatalogRescanService>(),
    ),
  );
  if (getIt.isRegistered<SessionListRefreshService>()) {
    getIt.unregister<SessionListRefreshService>();
  }
  getIt.registerFactoryParam<SessionListRefreshService, ProjectInventoryService, SessionWindowService>(
    (projectInventory, window) => SessionListRefreshService(
      projectInventory: projectInventory,
      window: window,
      catalogRescanService: getIt<CatalogRescanService>(),
    ),
  );
  if (getIt.isRegistered<SessionWindowService>()) {
    getIt.unregister<SessionWindowService>();
  }
  // The test bridges predate session pages: the window lists each project.s
  // sessions through [projectRepository], as the screens stub them.
  getIt.registerFactoryParam<SessionWindowService, AllSessionsMode, ProjectInventoryService>(
    (mode, projectInventory) => SessionWindowService(
      mode: mode,
      projectInventory: projectInventory,
      sessionRepository: _PagelessSessionRepository(),
      projectRepository: projectRepository,
      connectionService: getIt<ConnectionService>(),
      sseEventTracker: getIt<SseEventTracker>(),
      sessionUnseenTracker: getIt<SessionUnseenTracker>(),
      catalogRescanService: getIt<CatalogRescanService>(),
    ),
  );
}

class _PagelessSessionRepository() extends Mock implements SessionRepository {
  @override
  Future<SessionPageResult> getSessionPage({required SessionPageRequest request}) async =>
      const SessionPageUnsupported();
}

class _MockSessionListFilterTracker() extends Mock implements SessionListFilterTracker;

/// The phone home as the router mounts it: in the signed-in scope, under the
/// computer cubits the signed-in shell provides, built from the services
/// [registerListServices] registers.
Widget testHome() {
  // Every project listed, as the home starts.
  final filterTracker = _MockSessionListFilterTracker();
  when(() => filterTracker.projectId).thenAnswer((_) => BehaviorSubject<String?>.seeded(null).stream);
  return SessionScope(
    createProjectInventory: getIt.call<ProjectInventoryService>,
    createSessionWindow: ({required mode, required projectInventory}) =>
        getIt<SessionWindowService>(param1: mode, param2: projectInventory),
    createRefreshService: ({required projectInventory, required window}) =>
        getIt<SessionListRefreshService>(param1: projectInventory, param2: window),
    sessionCleanupService: SessionCleanupService(repository: MockSessionRepository()),
    sessionLaunchService: idleSessionLaunchService(),
    connectionService: getIt<ConnectionService>(),
    filterTracker: filterTracker,
    sseEventTracker: getIt<SseEventTracker>(),
    sessionUnseenTracker: getIt<SessionUnseenTracker>(),
    alertNavigatorKey: null,
    child: MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => BridgeIdentityCubit(
            registeredBridgesService: getIt<RegisteredBridgesService>(),
            connectionService: getIt<ConnectionService>(),
            selectedComputerService: getIt<SelectedComputerService>(),
          ),
        ),
        BlocProvider(
          create: (_) => ComputerSwitcherCubit(
            registeredBridgesService: getIt<RegisteredBridgesService>(),
            connectionService: getIt<ConnectionService>(),
            selectedComputerService: getIt<SelectedComputerService>(),
            activeBridgeLocality: getIt<ActiveBridgeLocality>(),
          ),
        ),
      ],
      child: const HomeScreen(),
    ),
  );
}

class _MockAllSessionsCubit() extends MockCubit<AllSessionsState> implements AllSessionsCubit;

class _MockProjectListCubit() extends MockCubit<ProjectListState> implements ProjectListCubit;

/// The home's list with [session] as its only row, acting through [actions]
/// and the real [dispatcher]. An archived session lists as Archived does.
///
/// Under a router, not a plain MaterialApp: action sheets close through
/// GoRouter, which the lint requires over direct Navigator.
Widget sessionRowApp({
  required SessionListCubit actions,
  required SessionListActionDispatcher dispatcher,
  required Session session,
}) {
  const project = ProjectSummary(id: "project-1", name: "Project One", path: "/project-1", time: null);
  final sessions = _MockAllSessionsCubit();
  final rows = [
    AllSessionsRow(
      session: session,
      project: project,
      isRunning: false,
      isUnseen: session.unseen,
      isAwaitingInput: false,
      isRetrying: false,
      backgroundTaskCount: 0,
    ),
  ];
  whenListen(
    sessions,
    const Stream<AllSessionsState>.empty(),
    initialState: AllSessionsState(
      projectId: null,
      query: "",
      quickFilter: SessionListQuickFilter.all,
      rows: rows,
      counts: const SessionListChipCounts(all: 1, running: 0, unread: 0),
      loadMore: null,
      awaitingAnswer: false,
      failure: null,
      isLoading: false,
      scratchProjectId: null,
      defaultProjectId: null,
    ),
  );
  when(() => sessions.mode).thenReturn(
    session.time?.archived == null ? AllSessionsMode.active : AllSessionsMode.archived,
  );
  when(() => sessions.setHiddenSessionIds(sessionIds: any(named: "sessionIds"))).thenReturn(null);
  final projects = _MockProjectListCubit();
  whenListen(
    projects,
    const Stream<ProjectListState>.empty(),
    initialState: const ProjectListState.loaded(projects: [project], folderProjects: [project], scratchProject: null),
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => Scaffold(
          body: CustomScrollView(
            slivers: [
              AllSessionsList(
                onSessionTap: ({required row}) {},
                actionDispatcher: dispatcher,
                createActionCubit: ({required projectId, required session}) => actions,
                selectedSessionId: null,
                disconnectedBuilder: ({required context, required state}) => const SliverToBoxAdapter(),
                emptyState: const SizedBox.shrink(),
                header: null,
                endClearance: 0,
              ),
            ],
          ),
        ),
      ),
    ],
  );
  return MultiBlocProvider(
    providers: [
      BlocProvider<AllSessionsCubit>.value(value: sessions),
      BlocProvider<ProjectListCubit>.value(value: projects),
      BlocProvider(
        create: (_) =>
            PendingSessionArchiveCubit(cleanupService: SessionCleanupService(repository: MockSessionRepository())),
      ),
      RepositoryProvider<SessionWindowService>.value(value: _emptySessionWindow()),
      RepositoryProvider(create: (_) => idleSessionLaunchService()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

class _MockSessionWindowService() extends Mock implements SessionWindowService;

/// A window that lists no sessions and never loads, for the launching rows of
/// a list whose rows a test provides itself.
SessionWindowService _emptySessionWindow() {
  final window = _MockSessionWindowService();
  when(() => window.state).thenAnswer(
    (_) => BehaviorSubject<SessionWindowState>.seeded(
      const SessionWindowLoaded(
        sessions: [],
        counts: SessionPageCounts(all: 0, running: 0, unread: 0),
        nextCursor: null,
        loadMore: SessionWindowLoadMore.idle,
        awaitingAnswer: false,
      ),
    ).stream,
  );
  when(() => window.key).thenReturn((projectId: null, query: null, filter: SessionListQuickFilter.all));
  return window;
}

class MockFirebaseCrashlytics() extends Mock implements FirebaseCrashlytics;

class MockFirebaseAnalytics() extends Mock implements FirebaseAnalytics;

// ---------------------------------------------------------------------------
// Fake classes — for registerFallbackValue
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// registerAllFallbackValues
// ---------------------------------------------------------------------------

/// Registers all fallback values required by mocktail argument matchers.
///
/// Call once in [setUpAll] before any test group that uses [any()] or
/// [captureAny()] for [ServerConnectionConfig] or [Uri] parameters.
void registerAllFallbackValues() {
  registerCoreFallbackValues();
  registerFallbackValue(http.MultipartFile.fromString("audio", ""));
  registerFallbackValue(AuthProvider.github);
}

/// Finds the brand artwork [PregoBrandLogo] draws for [pluginId].
///
/// Matched by asset rather than by rendered pixels: the artwork is what the
/// component promises for a harness it knows, and loading it would mean
/// decoding an SVG per assertion. Monochrome marks ship a `_light` and a
/// `_dark` export, so the basename is matched with that optional suffix.
Finder findBrandLogo(String pluginId) => find.byWidgetPredicate((widget) {
  if (widget is! SvgPicture) return false;
  final loader = widget.bytesLoader;
  return loader is SvgAssetLoader &&
      RegExp("/${RegExp.escape(pluginId)}(_light|_dark)?\\.svg\$").hasMatch(loader.assetName);
}, description: "brand artwork for $pluginId");
