import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/filesystem_api.dart";
import "package:sesori_dart_core/src/api/project_api.dart";
import "package:sesori_dart_core/src/api/session_api.dart";
import "package:sesori_dart_core/src/api/storage/composer_draft_storage.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/capabilities/session/session_service.dart";
import "package:sesori_dart_core/src/foundation/models/product_analytics/product_analytics_event.dart";
import "package:sesori_dart_core/src/foundation/models/session_options/session_options_request_mode.dart";
import "package:sesori_dart_core/src/platform/lifecycle_source.dart";
import "package:sesori_dart_core/src/platform/route_source.dart";
import "package:sesori_dart_core/src/repositories/bridge_repository.dart";
import "package:sesori_dart_core/src/repositories/composer_draft_repository.dart";
import "package:sesori_dart_core/src/repositories/models/analytics_delivery_result.dart";
import "package:sesori_dart_core/src/repositories/models/plugin_discovery_snapshot.dart";
import "package:sesori_dart_core/src/repositories/models/session_options_repository_result.dart";
import "package:sesori_dart_core/src/repositories/plugin_preference_repository.dart";
import "package:sesori_dart_core/src/repositories/plugin_repository.dart";
import "package:sesori_dart_core/src/repositories/project_repository.dart";
import "package:sesori_dart_core/src/repositories/registered_bridges_store.dart";
import "package:sesori_dart_core/src/repositories/session_repository.dart";
import "package:sesori_dart_core/src/routing/app_routes.dart";
import "package:sesori_dart_core/src/services/models/product_analytics_state.dart";
import "package:sesori_dart_core/src/services/models/session_activity_info.dart";
import "package:sesori_dart_core/src/services/models/session_list_item_state.dart";
import "package:sesori_dart_core/src/services/product_analytics_service.dart";
import "package:sesori_dart_core/src/services/project_viewing_service.dart";
import "package:sesori_dart_core/src/services/registered_bridges_service.dart";
import "package:sesori_dart_core/src/services/session_unseen_tracker.dart";
import "package:sesori_dart_core/src/services/session_viewing_service.dart";
import "package:sesori_dart_core/src/services/sse_event_tracker.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

/// A [LifecycleSource] seeded as resumed, for cubits that subscribe to
/// lifecycle. Call [emitState] to drive transitions in tests.
class FakeLifecycleSource() implements LifecycleSource {
  final BehaviorSubject<LifecycleState> _state = BehaviorSubject.seeded(LifecycleState.resumed);

  @override
  ValueStream<LifecycleState> get lifecycleStateStream => _state.stream;

  void emitState(LifecycleState state) => _state.add(state);

  void close() => _state.close();
}

class MockSessionViewingService() extends Mock implements SessionViewingService;

/// A [MockSessionViewingService] with its void methods pre-stubbed, for cubits
/// that declare a viewing session on load/close.
MockSessionViewingService stubbedSessionViewingService() {
  final mock = MockSessionViewingService();
  when(() => mock.setViewingSession(any())).thenReturn(null);
  when(() => mock.clearViewingSession(any())).thenReturn(null);
  return mock;
}

class MockProjectViewingService() extends Mock implements ProjectViewingService;

MockProjectViewingService stubbedProjectViewingService() {
  final mock = MockProjectViewingService();
  when(
    () => mock.beginListClaim(projectId: any(named: "projectId")),
  ).thenAnswer((_) => ProjectViewClaim());
  when(
    () => mock.beginDetailClaim(projectId: any(named: "projectId")),
  ).thenAnswer((_) => ProjectViewClaim());
  when(mock.beginWideListPaneClaim).thenAnswer((_) => ProjectViewPaneClaim());
  when(
    () => mock.markClaimReady(
      claim: any(named: "claim"),
      projectId: any(named: "projectId"),
    ),
  ).thenReturn(null);
  when(() => mock.markClaimFailed(claim: any(named: "claim"))).thenReturn(null);
  when(() => mock.releaseClaim(claim: any(named: "claim"))).thenReturn(null);
  when(
    () => mock.setWideListPaneVisible(
      claim: any(named: "claim"),
      isVisible: any(named: "isVisible"),
    ),
  ).thenReturn(null);
  when(
    () => mock.releaseWideListPaneClaim(claim: any(named: "claim")),
  ).thenReturn(null);
  when(mock.onDispose).thenAnswer((_) async {});
  return mock;
}

/// In-memory [SessionUnseenTracker] stand-in mirroring its lean contract:
/// overwrite-only maps plus a tick guard. Tests drive it via [emitProjectUnseen]
/// / [emitSessionUnseen] or the real seed/apply methods.
class FakeSessionUnseenTracker() extends Mock implements SessionUnseenTracker {
  final BehaviorSubject<Map<String, bool>> _projectUnseen = BehaviorSubject.seeded(const {});
  final BehaviorSubject<Map<String, Map<String, SessionListItemState>>> _sessionUnseen = BehaviorSubject.seeded(
    const {},
  );

  @override
  ValueStream<Map<String, bool>> get projectUnseen => _projectUnseen.stream;

  @override
  Map<String, bool> get currentProjectUnseen => _projectUnseen.value;

  @override
  ValueStream<Map<String, Map<String, SessionListItemState>>> get sessionUnseen => _sessionUnseen.stream;

  @override
  Map<String, Map<String, SessionListItemState>> get currentSessionUnseen => _sessionUnseen.value;

  int _tick = 0;
  final Map<String, int> _projectTick = {};

  @override
  int get tick => _tick;

  final List<({String projectId, Map<String, SessionListItemState> stateBySessionId})> seededSessions = [];

  @override
  void seedProjects(Map<String, bool> unseenByProjectId, {required int sinceTick}) {
    _projectUnseen.add({..._projectUnseen.value, ...unseenByProjectId});
  }

  @override
  void seedSessions({
    required String projectId,
    required Map<String, SessionListItemState> stateBySessionId,
    required int sinceTick,
  }) {
    seededSessions.add((projectId: projectId, stateBySessionId: stateBySessionId));
    if ((_projectTick[projectId] ?? 0) > sinceTick) return;
    final sessions = Map<String, Map<String, SessionListItemState>>.from(_sessionUnseen.value);
    final current = sessions[projectId] ?? const <String, SessionListItemState>{};
    sessions[projectId] = {
      for (final entry in stateBySessionId.entries)
        entry.key: (
          unseen: entry.value.unseen,
          lastUserActivityAt: latestUserActivityAt(
            first: current[entry.key]?.lastUserActivityAt,
            second: entry.value.lastUserActivityAt,
          ),
        ),
    };
    _sessionUnseen.add(sessions);
  }

  @override
  void applyLocalSessionUnseen({
    required String projectId,
    required String sessionId,
    required bool unseen,
  }) {
    _projectTick[projectId] = ++_tick;
    final sessions = Map<String, Map<String, SessionListItemState>>.from(_sessionUnseen.value);
    final projectSessions = Map<String, SessionListItemState>.from(sessions[projectId] ?? const {});
    projectSessions[sessionId] = (
      unseen: unseen,
      lastUserActivityAt: projectSessions[sessionId]?.lastUserActivityAt,
    );
    sessions[projectId] = projectSessions;
    _sessionUnseen.add(sessions);
  }

  void emitProjectUnseen(Map<String, bool> unseen) => _projectUnseen.add(unseen);

  void emitSessionUnseen(Map<String, Map<String, SessionListItemState>> unseen) {
    for (final projectId in unseen.keys) {
      _projectTick[projectId] = ++_tick;
    }
    _sessionUnseen.add(unseen);
  }
}

class MockProjectApi() extends Mock implements ProjectApi;

class MockFilesystemApi() extends Mock implements FilesystemApi;

class MockProjectRepository() extends Mock implements ProjectRepository;

class MockSessionApi() extends Mock implements SessionApi;

class MockSessionService() extends Mock implements SessionService;

class MockSessionRepository() extends Mock implements SessionRepository;

class MockProductAnalyticsService() extends Mock implements ProductAnalyticsService;

MockProductAnalyticsService stubbedProductAnalyticsService() {
  final mock = MockProductAnalyticsService();
  final states = BehaviorSubject<ProductAnalyticsState>.seeded(ProductAnalyticsState.initial);
  addTearDown(states.close);
  when(
    () => mock.logEvent(
      event: any(named: "event"),
      occurredAtUtc: any(named: "occurredAtUtc"),
    ),
  ).thenAnswer((_) async => AnalyticsDeliveryResult.acceptedBySdk);
  when(() => mock.state).thenAnswer((_) => states.value);
  when(() => mock.stateStream).thenAnswer((_) => states.stream);
  return mock;
}

ComposerDraftRepository inMemoryComposerDraftRepository() => ComposerDraftRepository(storage: ComposerDraftStorage());

class MockBridgeRepository() extends Mock implements BridgeRepository;

class MockPluginRepository() extends Mock implements PluginRepository;

MockPluginRepository stubbedPluginRepository({
  List<PluginMetadata> plugins = const <PluginMetadata>[],
}) {
  final mock = MockPluginRepository();
  when(mock.listPlugins).thenAnswer(
    (_) async => ApiResponse.success(
      PluginDiscoverySnapshot(
        bridgeId: "bridge-test",
        supportsSessionOptions: true,
        plugins: plugins,
      ),
    ),
  );
  return mock;
}

class MockPluginPreferenceRepository() extends Mock implements PluginPreferenceRepository;

class MockRegisteredBridgesStore() extends Mock implements RegisteredBridgesStore;

class MockRegisteredBridgesService() extends Mock implements RegisteredBridgesService;

class MockFailureReporter() extends Mock implements FailureReporter;

class MockConnectionService() extends Mock implements ConnectionService {
  final StreamController<void> _dataMayBeStale = StreamController<void>.broadcast();

  @override
  Stream<void> get dataMayBeStale => _dataMayBeStale.stream;

  void emitDataMayBeStale() => _dataMayBeStale.add(null);
}

class MockRouteSource({AppRouteDef? initialRoute, @override var String? currentLocation})
    extends Mock
    implements RouteSource {
  final BehaviorSubject<AppRouteDef?> _currentRoute = BehaviorSubject.seeded(initialRoute);

  @override
  ValueStream<AppRouteDef?> get currentRouteStream => _currentRoute.stream;

  AppRouteDef? get currentRoute => _currentRoute.value;

  void emitRoute(AppRouteDef? route) => _currentRoute.add(route);
}

class MockSseEventTracker() extends Mock implements SseEventTracker {
  final BehaviorSubject<Map<String, int>> _projectActivity = BehaviorSubject.seeded(const {});
  final BehaviorSubject<Map<String, Map<String, SessionActivityInfo>>> _sessionActivity = BehaviorSubject.seeded(
    const {},
  );
  final BehaviorSubject<Map<String, int>> _projectTimestampUpdates = BehaviorSubject.seeded(const {});

  @override
  ValueStream<Map<String, int>> get projectActivity => _projectActivity.stream;

  @override
  Map<String, int> get currentProjectActivity => _projectActivity.value;

  @override
  ValueStream<Map<String, Map<String, SessionActivityInfo>>> get sessionActivity => _sessionActivity.stream;

  @override
  Map<String, Map<String, SessionActivityInfo>> get currentSessionActivity => _sessionActivity.value;

  @override
  ValueStream<Map<String, int>> get projectTimestampUpdates => _projectTimestampUpdates.stream;

  @override
  Map<String, int> get currentProjectTimestampUpdates => _projectTimestampUpdates.value;

  void emitProjectActivity(Map<String, int> activity) => _projectActivity.add(activity);

  void emitSessionActivity(Map<String, Map<String, SessionActivityInfo>> activity) => _sessionActivity.add(activity);

  void emitProjectTimestampUpdate(Map<String, int> update) => _projectTimestampUpdates.add(update);
}

class FakeUri() extends Fake implements Uri;

void delegateSessionRepositoryToService({
  required MockSessionRepository repository,
  required MockSessionService service,
}) {
  when(() => repository.abortSession(sessionId: any(named: "sessionId"))).thenAnswer(
    (invocation) => service.abortSession(sessionId: invocation.namedArguments[#sessionId]! as String),
  );
  when(
    () => repository.replyToQuestion(
      requestId: any(named: "requestId"),
      sessionId: any(named: "sessionId"),
      answers: any(named: "answers"),
    ),
  ).thenAnswer(
    (invocation) => service.replyToQuestion(
      requestId: invocation.namedArguments[#requestId]! as String,
      sessionId: invocation.namedArguments[#sessionId]! as String,
      answers: invocation.namedArguments[#answers]! as List<ReplyAnswer>,
    ),
  );
  when(
    () => repository.rejectQuestion(
      requestId: any(named: "requestId"),
      sessionId: any(named: "sessionId"),
    ),
  ).thenAnswer(
    (invocation) => service.rejectQuestion(
      requestId: invocation.namedArguments[#requestId]! as String,
      sessionId: invocation.namedArguments[#sessionId]! as String,
    ),
  );
  when(
    () => repository.getMessages(
      sessionId: any(named: "sessionId"),
      limit: any(named: "limit"),
      before: any(named: "before"),
    ),
  ).thenAnswer(
    (invocation) => service.getMessages(
      sessionId: invocation.namedArguments[#sessionId]! as String,
      limit: invocation.namedArguments[#limit] as int?,
      before: invocation.namedArguments[#before] as int?,
    ),
  );
  when(
    () => repository.getPendingQuestions(sessionId: any(named: "sessionId")),
  ).thenAnswer(
    (invocation) => service.getPendingQuestions(sessionId: invocation.namedArguments[#sessionId]! as String),
  );
  when(
    () => repository.getPendingPermissions(sessionId: any(named: "sessionId")),
  ).thenAnswer(
    (invocation) => service.getPendingPermissions(sessionId: invocation.namedArguments[#sessionId]! as String),
  );
  when(
    () => repository.getQueuedPrompts(sessionId: any(named: "sessionId")),
  ).thenAnswer((_) async => ApiResponse.success(const QueuedPromptResponse(data: <QueuedSessionPrompt>[])));
  when(
    () => repository.getChildren(sessionId: any(named: "sessionId")),
  ).thenAnswer(
    (invocation) => service.getChildren(sessionId: invocation.namedArguments[#sessionId]! as String),
  );
  when(() => repository.getSessionStatuses()).thenAnswer((_) => service.getSessionStatuses());
  delegateSessionOptionsRepositoryToService(repository: repository, service: service);
  when(
    () => repository.listAgents(
      projectId: any(named: "projectId"),
      pluginId: any(named: "pluginId"),
    ),
  ).thenAnswer(
    (invocation) => service.listAgents(
      projectId: invocation.namedArguments[#projectId] as String,
      pluginId: invocation.namedArguments[#pluginId] as String,
    ),
  );
  when(
    () => repository.listProviders(
      projectId: any(named: "projectId"),
      pluginId: any(named: "pluginId"),
    ),
  ).thenAnswer(
    (invocation) => service.listProviders(
      projectId: invocation.namedArguments[#projectId] as String,
      pluginId: invocation.namedArguments[#pluginId] as String,
    ),
  );
  when(
    () => repository.listCommands(
      projectId: any(named: "projectId"),
      pluginId: any(named: "pluginId"),
    ),
  ).thenAnswer(
    (invocation) => service.listCommands(
      projectId: invocation.namedArguments[#projectId] as String?,
      pluginId: invocation.namedArguments[#pluginId] as String,
    ),
  );
  when(
    () => repository.sendMessage(
      promptId: any(named: "promptId"),
      attachments: const [],
      sessionId: any(named: "sessionId"),
      text: any(named: "text"),
      agent: any(named: "agent"),
      model: any(named: "model"),
      variant: any(named: "variant"),
      command: any(named: "command"),
    ),
  ).thenAnswer(
    (invocation) => service.sendMessage(
      promptId: "prompt-1",
      attachments: const [],
      sessionId: invocation.namedArguments[#sessionId]! as String,
      text: invocation.namedArguments[#text]! as String,
      agent: invocation.namedArguments[#agent] as String?,
      providerID: (invocation.namedArguments[#model] as PromptModel?)?.providerID,
      modelID: (invocation.namedArguments[#model] as PromptModel?)?.modelID,
      variant: invocation.namedArguments[#variant] as SessionVariant?,
      command: invocation.namedArguments[#command] as String?,
    ),
  );
}

/// Adapts existing new-session tests that stub the three legacy service calls
/// to the aggregate repository seam used by the modern client flow.
void delegateSessionOptionsRepositoryToService({
  required MockSessionRepository repository,
  required MockSessionService service,
}) {
  Future<SessionOptionsRepositoryResult> loadOptions(Invocation invocation) async {
    final projectId = invocation.namedArguments[#projectId]! as String;
    final pluginId = invocation.namedArguments[#pluginId]! as String;
    final (agents, providers, commands) = await (
      service.listAgents(projectId: projectId, pluginId: pluginId),
      service.listProviders(projectId: projectId, pluginId: pluginId),
      service.listCommands(projectId: projectId, pluginId: pluginId),
    ).wait;
    return switch ((agents, providers, commands)) {
      (
        SuccessResponse(data: final agentData),
        SuccessResponse(data: final providerData),
        SuccessResponse(data: final commandData),
      ) =>
        SessionOptionsRepositoryAvailable(
          isStale: false,
          catalog: SessionOptionsCatalog(
            agents: agentData.agents,
            providers: providerData.items,
            providersConnectedOnly: providerData.connectedOnly,
            commands: commandData.items,
          ),
        ),
      (ErrorResponse(:final error), _, _) => SessionOptionsRepositoryFailure(error: error),
      (_, ErrorResponse(:final error), _) => SessionOptionsRepositoryFailure(error: error),
      (_, _, ErrorResponse(:final error)) => SessionOptionsRepositoryFailure(error: error),
    };
  }

  when(
    () => repository.loadSessionOptions(
      projectId: any(named: "projectId"),
      pluginId: any(named: "pluginId"),
      mode: any(named: "mode"),
    ),
  ).thenAnswer(loadOptions);
}

void stubSessionRepositoryGetSession({
  required MockSessionRepository repository,
  required String sessionId,
  Session? session,
}) {
  when(() => repository.getSession(sessionId: sessionId)).thenAnswer(
    (_) async => ApiResponse.success(session ?? testSession(id: sessionId)),
  );
}

void registerAllFallbackValues() {
  registerFallbackValue(const ServerConnectionConfig(relayHost: "fake.example.com"));
  registerFallbackValue(FakeUri());
  registerFallbackValue(StackTrace.empty);
  registerFallbackValue(const ProductAnalyticsEvent.analyticsSchemaReady());
  registerFallbackValue(SessionOptionsRequestMode.dynamic);
  registerFallbackValue(ProjectViewClaim());
  registerFallbackValue(ProjectViewPaneClaim());
  registerFallbackValue(DateTime.utc(2026));
}

Project testProject({String? id, String? path, String? name}) {
  return Project.fromJson({
    "id": id ?? "project-1",
    "path": path ?? "/home/user/my-project",
    "name": name,
    "time": {
      "created": 1700000000000,
      "updated": 1700000000000,
    },
  });
}

ProjectSummary testProjectSummary({String? id, String? path, String? name}) {
  return ProjectSummary.fromJson({
    "id": id ?? "project-1",
    "path": path ?? "/home/user/my-project",
    "name": name,
    "time": {
      "created": 1700000000000,
      "updated": 1700000000000,
    },
  });
}

Session testSession({
  String? id,
  String? title,
  DateTime? archivedAt,
  bool unseen = false,
  int? lastUserActivityAt,
  String pluginId = "plugin-1",
}) {
  return Session(
    branchName: null,
    id: id ?? "session-1",
    pluginId: pluginId,
    projectID: "project-1",
    directory: "/home/user/my-project",
    parentID: null,
    title: title,
    pullRequest: null,
    time: SessionTime(
      created: 1700000000000,
      updated: 1700000000000,
      archived: archivedAt?.millisecondsSinceEpoch,
    ),
    promptDefaults: null,
    unseen: unseen,
    lastUserActivityAt: lastUserActivityAt,
  );
}

HealthResponse testHealthResponse() {
  return const HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
}

BridgeSummary testBridgeSummary({String? id, String? name, DateTime? addedAt, DateTime? lastSeenAt}) {
  return BridgeSummary(
    id: id ?? "br_test1234",
    name: name ?? "test-macbook",
    platform: "macos",
    addedAt: addedAt ?? DateTime.utc(2026, 1, 1),
    lastSeenAt: lastSeenAt,
  );
}

CommandInfo testCommandInfo({
  String name = "review",
  String template = "/review {{file}}",
}) {
  return CommandInfo(
    name: name,
    template: template,
    hints: const ["Optional arguments"],
    description: "Run $name",
    agent: null,
    model: null,
    provider: null,
    source: CommandSource.command,
    subtask: false,
  );
}
