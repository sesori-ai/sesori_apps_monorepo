import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/client/relay_http_client.dart";
import "../api/filesystem_api.dart";
import "../api/project_api.dart";
import "../api/session_api.dart";
import "../api/storage/composer_draft_storage.dart";
import "../capabilities/relay/relay_client.dart";
import "../capabilities/relay/room_key_storage.dart";
import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/server_connection_config.dart";
import "../capabilities/voice/voice_api.dart";
import "../foundation/models/composer/composer_attachment.dart";
import "../foundation/models/product_analytics/product_analytics_event.dart";
import "../foundation/models/session_options/session_options_request_mode.dart";
import "../platform/deep_link_source.dart";
import "../platform/lifecycle_source.dart";
import "../platform/notification_canceller.dart";
import "../platform/route_source.dart";
import "../platform/url_launcher.dart";
import "../repositories/bridge_repository.dart";
import "../repositories/composer_draft_repository.dart";
import "../repositories/models/plugin_discovery_snapshot.dart";
import "../repositories/models/session_options_repository_result.dart";
import "../repositories/permission_repository.dart";
import "../repositories/plugin_preference_repository.dart";
import "../repositories/plugin_repository.dart";
import "../repositories/project_repository.dart";
import "../repositories/registered_bridges_store.dart";
import "../repositories/session_repository.dart";
import "../routing/app_routes.dart";
import "../services/catalog_rescan_service.dart";
import "../services/hosted_voice_input_service.dart";
import "../services/models/catalog_rescan_state.dart";
import "../services/models/session_activity_info.dart";
import "../services/models/session_list_item_state.dart";
import "../services/product_analytics_service.dart";
import "../services/project_viewing_service.dart";
import "../services/project_voice_glossary_service.dart";
import "../services/registered_bridges_service.dart";
import "../services/session_detail_load_service.dart";
import "../services/session_unseen_tracker.dart";
import "../services/session_viewing_service.dart";
import "../services/sse_event_tracker.dart";

const String? _noString = null;
const int? _noInt = null;
const DateTime? _noDateTime = null;
const AppRouteDef? _noAppRouteDef = null;
const Session? _noSession = null;
const SessionPromptDefaults? _noSessionPromptDefaults = null;

/// A [LifecycleSource] seeded as resumed, for cubits that subscribe to
/// lifecycle. Call [emitState] to drive transitions in tests.
class FakeLifecycleSource() implements LifecycleSource {
  final BehaviorSubject<LifecycleState> _state = BehaviorSubject.seeded(LifecycleState.resumed);

  @override
  ValueStream<LifecycleState> get lifecycleStateStream => _state.stream;

  void emitState(LifecycleState state) => _state.add(state);

  Future<void> close() async {
    if (!_state.isClosed) await _state.close();
  }

  Future<void> dispose() => close();
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
    final projects = Map<String, bool>.from(_projectUnseen.value);
    for (final entry in unseenByProjectId.entries) {
      if ((_projectTick[entry.key] ?? 0) > sinceTick) continue;
      projects[entry.key] = entry.value;
    }
    _projectUnseen.add(projects);
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

  @override
  Future<void> onDispose() async {
    await Future.wait([
      if (!_projectUnseen.isClosed) _projectUnseen.close(),
      if (!_sessionUnseen.isClosed) _sessionUnseen.close(),
    ]);
  }
}

class MockProjectApi() extends Mock implements ProjectApi;

class MockOAuthFlowProvider() extends Mock implements OAuthFlowProvider;

class MockAuthTokenProvider() extends Mock implements AuthTokenProvider;

class MockAuthenticatedHttpApiClient() extends Mock implements AuthenticatedHttpApiClient;

class MockHttpApiClient() extends Mock implements HttpApiClient;

class MockRelayCryptoService() extends Mock implements RelayCryptoService;

class MockRelayClient() extends Mock implements RelayClient;

class MockVoiceApi() extends Mock implements VoiceApi;

class MockSecureStorage() extends Mock implements SecureStorage;

class MockDeepLinkSource() extends Mock implements DeepLinkSource;

class MockUrlLauncher() extends Mock implements UrlLauncher;

class MockLifecycleSource() extends Mock implements LifecycleSource {
  final BehaviorSubject<LifecycleState> _state = BehaviorSubject.seeded(LifecycleState.resumed);

  @override
  ValueStream<LifecycleState> get lifecycleStateStream => _state.stream;

  void emitState(LifecycleState state) => _state.add(state);
}

class MockFilesystemApi() extends Mock implements FilesystemApi;

class MockProjectRepository() extends Mock implements ProjectRepository;

class MockHostedVoiceInputService() extends Mock implements HostedVoiceInputService;

class MockProjectVoiceGlossaryService() extends Mock implements ProjectVoiceGlossaryService;

class MockSessionApi() extends Mock implements SessionApi;

class MockSessionRepository() extends Mock implements SessionRepository;

class MockProductAnalyticsService() extends Mock implements ProductAnalyticsService;

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

class MockRouteSource({
  AppRouteDef? initialRoute = _noAppRouteDef,
  @override var String? currentLocation = _noString,
}) extends Mock implements RouteSource {
  final BehaviorSubject<AppRouteDef?> _currentRoute = BehaviorSubject.seeded(initialRoute);

  @override
  ValueStream<AppRouteDef?> get currentRouteStream => _currentRoute.stream;

  AppRouteDef? get currentRoute => _currentRoute.value;

  void emitRoute(AppRouteDef? route) => _currentRoute.add(route);

  Future<void> dispose() async {
    if (!_currentRoute.isClosed) await _currentRoute.close();
  }
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

  @override
  Future<void> onDispose() async {
    await Future.wait([
      if (!_projectActivity.isClosed) _projectActivity.close(),
      if (!_sessionActivity.isClosed) _sessionActivity.close(),
      if (!_projectTimestampUpdates.isClosed) _projectTimestampUpdates.close(),
    ]);
  }
}

class FakeUri() extends Fake implements Uri;

T _namedArgument<T>({required Invocation invocation, required Symbol name}) {
  final value = invocation.namedArguments[name];
  if (value is T) return value;
  throw StateError(
    "Named argument ${name.toString()} must be ${T.toString()}, got ${value.runtimeType.toString()}",
  );
}

void delegateSessionRepository({
  required MockSessionRepository repository,
  required MockSessionRepository source,
}) {
  when(() => repository.abortSession(sessionId: any(named: "sessionId"))).thenAnswer(
    (invocation) => source.abortSession(
      sessionId: _namedArgument<String>(invocation: invocation, name: #sessionId),
    ),
  );
  when(
    () => repository.replyToQuestion(
      requestId: any(named: "requestId"),
      sessionId: any(named: "sessionId"),
      answers: any(named: "answers"),
    ),
  ).thenAnswer(
    (invocation) => source.replyToQuestion(
      requestId: _namedArgument<String>(invocation: invocation, name: #requestId),
      sessionId: _namedArgument<String>(invocation: invocation, name: #sessionId),
      answers: _namedArgument<List<ReplyAnswer>>(invocation: invocation, name: #answers),
    ),
  );
  when(
    () => repository.rejectQuestion(
      requestId: any(named: "requestId"),
      sessionId: any(named: "sessionId"),
    ),
  ).thenAnswer(
    (invocation) => source.rejectQuestion(
      requestId: _namedArgument<String>(invocation: invocation, name: #requestId),
      sessionId: _namedArgument<String>(invocation: invocation, name: #sessionId),
    ),
  );
  when(
    () => repository.getMessages(
      sessionId: any(named: "sessionId"),
      limit: any(named: "limit"),
      before: any(named: "before"),
    ),
  ).thenAnswer(
    (invocation) => source.getMessages(
      sessionId: _namedArgument<String>(invocation: invocation, name: #sessionId),
      limit: _namedArgument<int?>(invocation: invocation, name: #limit),
      before: _namedArgument<int?>(invocation: invocation, name: #before),
    ),
  );
  when(
    () => repository.getPendingQuestions(sessionId: any(named: "sessionId")),
  ).thenAnswer(
    (invocation) => source.getPendingQuestions(
      sessionId: _namedArgument<String>(invocation: invocation, name: #sessionId),
    ),
  );
  when(
    () => repository.getPendingPermissions(sessionId: any(named: "sessionId")),
  ).thenAnswer(
    (invocation) => source.getPendingPermissions(
      sessionId: _namedArgument<String>(invocation: invocation, name: #sessionId),
    ),
  );
  when(
    () => repository.getQueuedPrompts(sessionId: any(named: "sessionId")),
  ).thenAnswer((_) async => ApiResponse.success(const QueuedPromptResponse(data: <QueuedSessionPrompt>[])));
  when(
    () => repository.getChildren(sessionId: any(named: "sessionId")),
  ).thenAnswer(
    (invocation) => source.getChildren(
      sessionId: _namedArgument<String>(invocation: invocation, name: #sessionId),
    ),
  );
  when(() => repository.getSessionStatuses()).thenAnswer((_) => source.getSessionStatuses());
  delegateSessionOptionsRepository(repository: repository, source: source);
  when(
    () => repository.listAgents(
      projectId: any(named: "projectId"),
      pluginId: any(named: "pluginId"),
    ),
  ).thenAnswer(
    (invocation) => source.listAgents(
      projectId: _namedArgument<String>(invocation: invocation, name: #projectId),
      pluginId: _namedArgument<String>(invocation: invocation, name: #pluginId),
    ),
  );
  when(
    () => repository.listProviders(
      projectId: any(named: "projectId"),
      pluginId: any(named: "pluginId"),
    ),
  ).thenAnswer(
    (invocation) => source.listProviders(
      projectId: _namedArgument<String>(invocation: invocation, name: #projectId),
      pluginId: _namedArgument<String>(invocation: invocation, name: #pluginId),
    ),
  );
  when(
    () => repository.listCommands(
      projectId: any(named: "projectId"),
      pluginId: any(named: "pluginId"),
    ),
  ).thenAnswer(
    (invocation) => source.listCommands(
      projectId: _namedArgument<String>(invocation: invocation, name: #projectId),
      pluginId: _namedArgument<String>(invocation: invocation, name: #pluginId),
    ),
  );
  when(
    () => repository.sendMessage(
      promptId: any(named: "promptId"),
      attachments: any(named: "attachments"),
      sessionId: any(named: "sessionId"),
      text: any(named: "text"),
      agent: any(named: "agent"),
      model: any(named: "model"),
      variant: any(named: "variant"),
      command: any(named: "command"),
    ),
  ).thenAnswer(
    (invocation) => source.sendMessage(
      promptId: "prompt-1",
      attachments: _namedArgument<List<ComposerAttachment>>(invocation: invocation, name: #attachments),
      sessionId: _namedArgument<String>(invocation: invocation, name: #sessionId),
      text: _namedArgument<String>(invocation: invocation, name: #text),
      agent: _namedArgument<String?>(invocation: invocation, name: #agent),
      model: _namedArgument<PromptModel?>(invocation: invocation, name: #model),
      variant: _namedArgument<SessionVariant?>(invocation: invocation, name: #variant),
      command: _namedArgument<String?>(invocation: invocation, name: #command),
    ),
  );
}

/// Adapts existing new-session tests that stub the three legacy service calls
/// to the aggregate repository seam used by the modern client flow.
void delegateSessionOptionsRepository({
  required MockSessionRepository repository,
  required MockSessionRepository source,
}) {
  Future<SessionOptionsRepositoryResult> loadOptions(Invocation invocation) async {
    final projectId = _namedArgument<String>(invocation: invocation, name: #projectId);
    final pluginId = _namedArgument<String>(invocation: invocation, name: #pluginId);
    final (agents, providers, commands) = await (
      source.listAgents(projectId: projectId, pluginId: pluginId),
      source.listProviders(projectId: projectId, pluginId: pluginId),
      source.listCommands(projectId: projectId, pluginId: pluginId),
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
  Session? session = _noSession,
}) {
  when(() => repository.getSession(sessionId: sessionId)).thenAnswer(
    (_) async => ApiResponse.success(session ?? testSession(id: sessionId)),
  );
}

void registerCoreFallbackValues() {
  registerFallbackValue(const ServerConnectionConfig(relayHost: "fake.example.com", authToken: null));
  registerFallbackValue(FakeUri());
  registerFallbackValue(StackTrace.empty);
  registerFallbackValue(const ProductAnalyticsEvent.analyticsSchemaReady());
  registerFallbackValue(AccountStatus.existing);
  registerFallbackValue(SessionOptionsRequestMode.dynamic);
  registerFallbackValue(ProjectViewClaim());
  registerFallbackValue(ProjectViewPaneClaim());
  registerFallbackValue(DateTime.utc(2026));
  registerFallbackValue(Duration.zero);
  registerFallbackValue(const <ComposerAttachment>[]);
}

Project testProject({
  String? id = _noString,
  String? path = _noString,
  String? name = _noString,
}) {
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

ProjectSummary testProjectSummary({
  String? id = _noString,
  String? path = _noString,
  String? name = _noString,
}) {
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
  String? id = _noString,
  String? title = _noString,
  String? parentID = _noString,
  int? createdAt = _noInt,
  int? updatedAt = _noInt,
  DateTime? archivedAt = _noDateTime,
  SessionPromptDefaults? promptDefaults = _noSessionPromptDefaults,
  bool unseen = false,
  int? lastUserActivityAt = _noInt,
  String pluginId = "plugin-1",
  String? branchName = _noString,
}) {
  return Session(
    branchName: branchName,
    id: id ?? "session-1",
    pluginId: pluginId,
    projectID: "project-1",
    directory: "/home/user/my-project",
    parentID: parentID,
    title: title,
    pullRequest: null,
    time: SessionTime(
      created: createdAt ?? 1700000000000,
      updated: updatedAt ?? 1700000000000,
      archived: archivedAt?.millisecondsSinceEpoch,
    ),
    promptDefaults: promptDefaults,
    unseen: unseen,
    lastUserActivityAt: lastUserActivityAt,
  );
}

HealthResponse testHealthResponse() {
  return const HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false);
}

BridgeSummary testBridgeSummary({
  String? id = _noString,
  String? name = _noString,
  DateTime? addedAt = _noDateTime,
  DateTime? lastSeenAt = _noDateTime,
}) {
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

class MockPermissionRepository() extends Mock implements PermissionRepository;

class MockNotificationCanceller() extends Mock implements NotificationCanceller;

class MockRelayHttpApiClient() extends Mock implements RelayHttpApiClient;

class MockAuthSession() extends Mock implements AuthSession;

class MockSessionDetailLoadService() extends Mock implements SessionDetailLoadService;

class MockRoomKeyStorage() extends Mock implements RoomKeyStorage;

MessageWithParts testMessageWithParts({String? id = _noString}) {
  final messageId = id ?? "msg-1";
  return MessageWithParts(
    info: Message.assistant(
      id: messageId,
      sessionID: "session-1",
      agent: null,
      modelID: null,
      providerID: null,
      time: null,
    ),
    parts: [
      MessagePart.text(
        id: "part-1",
        sessionID: "session-1",
        messageID: messageId,
        text: "Hello, world!",
      ),
    ],
  );
}

SesoriQuestionAsked testSseQuestionAsked() => const SesoriQuestionAsked(
  id: "question-1",
  sessionID: "session-1",
  displaySessionId: null,
  questions: [
    QuestionInfo(
      question: "Which option would you like?",
      header: "Please choose",
      options: [
        QuestionOption(label: "Yes", description: "Proceed"),
        QuestionOption(label: "No", description: "Cancel"),
      ],
    ),
  ],
);

PendingQuestion testPendingQuestion() => const PendingQuestion(
  id: "question-1",
  sessionID: "session-1",
  displaySessionId: null,
  questions: [
    QuestionInfo(
      question: "Which option would you like?",
      header: "Please choose",
      options: [
        QuestionOption(label: "Yes", description: "Proceed"),
        QuestionOption(label: "No", description: "Cancel"),
      ],
    ),
  ],
);

SesoriQuestionAsked testMultiSseQuestionAsked({
  String id = "question-multi",
  String sessionID = "session-1",
}) => SesoriQuestionAsked(
  id: id,
  sessionID: sessionID,
  displaySessionId: null,
  questions: const [
    QuestionInfo(
      question: "Which language do you prefer?",
      header: "Language",
      options: [
        QuestionOption(label: "Dart", description: "Flutter language"),
        QuestionOption(label: "Kotlin", description: "Android language"),
      ],
    ),
    QuestionInfo(
      question: "Which IDE do you use?",
      header: "IDE",
      options: [
        QuestionOption(label: "VS Code", description: "Microsoft editor"),
        QuestionOption(label: "IntelliJ", description: "JetBrains IDE"),
      ],
    ),
    QuestionInfo(
      question: "Any additional notes?",
      header: "Notes",
      options: [],
      custom: true,
    ),
  ],
);

AgentInfo testAgentInfo() => const AgentInfo(
  name: "coder",
  description: "A coding assistant",
  model: null,
  mode: AgentMode.primary,
);

ProviderListResponse testProviderListResponse() => const ProviderListResponse(
  connectedOnly: false,
  items: [
    ProviderInfo(
      id: "anthropic",
      name: "Anthropic",
      defaultModelID: "claude-3-5-sonnet",
      models: {
        "claude-3-5-sonnet": ProviderModel(
          id: "claude-3-5-sonnet",
          providerID: "anthropic",
          name: "Claude 3.5 Sonnet",
          variants: ["xhigh"],
          family: null,
          releaseDate: null,
        ),
      },
    ),
  ],
);

AuthUser testAuthUser() => const AuthUser(
  id: "user-1",
  provider: AuthProvider.github,
  providerUserId: "12345678",
  providerUsername: "testuser",
);

/// In-memory [AuthSession] whose state can be driven from a test.
class FakeAuthSession({required AuthState initialState}) implements AuthSession {
  final BehaviorSubject<AuthState> _authStates = BehaviorSubject<AuthState>.seeded(initialState);

  @override
  ValueStream<AuthState> get authStateStream => _authStates.stream;

  @override
  AuthState get currentState => _authStates.value;

  void emit(AuthState state) => _authStates.add(state);

  Future<void> dispose() async {
    await _authStates.close();
  }

  @override
  Future<AuthUser?> getCurrentUser() async => null;

  @override
  Future<bool> hasLocallyValidSession() async => false;

  @override
  Future<void> invalidateAllSessions() async {}

  @override
  Future<void> logoutCurrentDevice() async {}

  @override
  Future<bool> restoreSession() async => false;

  @override
  Future<bool> restoreLocalSession() async => false;

  @override
  Future<AuthLoginResult> loginWithEmail({required String email, required String password}) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthLoginResult> loginWithApple({required String idToken, required String nonce}) async {
    throw UnimplementedError();
  }
}

/// A [CatalogRescanService] a test drives directly.
///
/// The real service owns a whole operation lifecycle; a consumer only cares
/// that it publishes state, announces committed catalog changes, and accepts
/// intents, so this exposes exactly those.
class FakeCatalogRescanService() implements CatalogRescanService {
  final BehaviorSubject<CatalogRescanState> _state = BehaviorSubject.seeded(
    const CatalogRescanState.idle(),
  );
  final StreamController<void> _catalogChanged = StreamController<void>.broadcast(sync: true);

  final List<void> _startAlls = [];
  final List<void> _cancels = [];
  final List<void> _dismisses = [];

  int get startAllCalls => _startAlls.length;
  int get cancelCalls => _cancels.length;
  int get dismissCalls => _dismisses.length;

  @override
  ValueStream<CatalogRescanState> get state => _state.stream;

  @override
  Stream<void> get catalogChanged => _catalogChanged.stream;

  /// Plugin ids passed to [start], in call order.
  final List<String> startedPluginIds = [];

  CatalogRescanStartResult _startResult = const CatalogRescanStartResult.accepted();

  /// Sets what [start] answers, so a test can drive a rejection.
  void stubStartResult(CatalogRescanStartResult result) => _startResult = result;

  @override
  Future<void> startAll() async => _startAlls.add(null);

  void Function()? _beforeStartAnswers;

  /// Sets a hook that runs inside [start] before it answers, so a test can
  /// drive the state the real service would already have published by then: a
  /// definite rejection settles the operation before the call returns.
  void stubBeforeStartAnswers(void Function() hook) => _beforeStartAnswers = hook;

  @override
  Future<CatalogRescanStartResult> start({required String pluginId}) async {
    startedPluginIds.add(pluginId);
    _beforeStartAnswers?.call();
    return _startResult;
  }

  @override
  Future<void> cancel() async => _cancels.add(null);

  @override
  void dismiss() => _dismisses.add(null);

  /// Publishes [next] as the current scan state.
  void emit(CatalogRescanState next) => _state.add(next);

  /// Announces that an import committed a durable catalog change.
  void emitCatalogChanged() => _catalogChanged.add(null);

  /// Closes both streams. Named to match `Disposable`, because `get_it` calls
  /// it on reset and every widget test that registers this fake goes through
  /// that path.
  @override
  Future<void> onDispose() async {
    if (_state.isClosed) return;
    await _state.close();
    await _catalogChanged.close();
  }
}
