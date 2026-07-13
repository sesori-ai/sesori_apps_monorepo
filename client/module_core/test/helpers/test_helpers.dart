import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/project_api.dart";
import "package:sesori_dart_core/src/api/session_api.dart";
import "package:sesori_dart_core/src/capabilities/project/project_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/capabilities/session/session_service.dart";
import "package:sesori_dart_core/src/platform/lifecycle_source.dart";
import "package:sesori_dart_core/src/platform/route_source.dart";
import "package:sesori_dart_core/src/repositories/bridge_repository.dart";
import "package:sesori_dart_core/src/repositories/project_repository.dart";
import "package:sesori_dart_core/src/repositories/registered_bridges_store.dart";
import "package:sesori_dart_core/src/repositories/session_repository.dart";
import "package:sesori_dart_core/src/routing/app_routes.dart";
import "package:sesori_dart_core/src/services/models/session_activity_info.dart";
import "package:sesori_dart_core/src/services/registered_bridges_service.dart";
import "package:sesori_dart_core/src/services/session_unseen_tracker.dart";
import "package:sesori_dart_core/src/services/session_viewing_service.dart";
import "package:sesori_dart_core/src/services/sse_event_tracker.dart";
import "package:sesori_shared/sesori_shared.dart";

/// A [LifecycleSource] seeded as resumed, for cubits that subscribe to
/// lifecycle. Call [emitState] to drive transitions in tests.
class FakeLifecycleSource implements LifecycleSource {
  final BehaviorSubject<LifecycleState> _state = BehaviorSubject.seeded(LifecycleState.resumed);

  @override
  ValueStream<LifecycleState> get lifecycleStateStream => _state.stream;

  void emitState(LifecycleState state) => _state.add(state);

  void close() => _state.close();
}

class MockSessionViewingService extends Mock implements SessionViewingService {}

/// A [MockSessionViewingService] with its void methods pre-stubbed, for cubits
/// that declare a viewing session on load/close.
MockSessionViewingService stubbedSessionViewingService() {
  final mock = MockSessionViewingService();
  when(() => mock.setViewingSession(any())).thenReturn(null);
  when(() => mock.clearViewingSession(any())).thenReturn(null);
  return mock;
}

/// In-memory [SessionUnseenTracker] stand-in mirroring its lean contract:
/// overwrite-only maps plus a tick guard. Tests drive it via [emitProjectUnseen]
/// / [emitSessionUnseen] or the real seed/apply methods.
class FakeSessionUnseenTracker extends Mock implements SessionUnseenTracker {
  final BehaviorSubject<Map<String, bool>> _projectUnseen = BehaviorSubject.seeded(const {});
  final BehaviorSubject<Map<String, Map<String, bool>>> _sessionUnseen = BehaviorSubject.seeded(const {});

  @override
  ValueStream<Map<String, bool>> get projectUnseen => _projectUnseen.stream;

  @override
  Map<String, bool> get currentProjectUnseen => _projectUnseen.value;

  @override
  ValueStream<Map<String, Map<String, bool>>> get sessionUnseen => _sessionUnseen.stream;

  @override
  Map<String, Map<String, bool>> get currentSessionUnseen => _sessionUnseen.value;

  @override
  int get tick => 0;

  final List<({String projectId, Map<String, bool> unseenBySessionId})> seededSessions = [];

  @override
  void seedProjects(Map<String, bool> unseenByProjectId, {required int sinceTick}) {
    _projectUnseen.add({..._projectUnseen.value, ...unseenByProjectId});
  }

  @override
  void seedSessions({
    required String projectId,
    required Map<String, bool> unseenBySessionId,
    required int sinceTick,
  }) {
    seededSessions.add((projectId: projectId, unseenBySessionId: unseenBySessionId));
    final sessions = Map<String, Map<String, bool>>.from(_sessionUnseen.value);
    sessions[projectId] = Map<String, bool>.from(unseenBySessionId);
    _sessionUnseen.add(sessions);
  }

  @override
  void applyLocalSessionUnseen({
    required String projectId,
    required String sessionId,
    required bool unseen,
  }) {
    final sessions = Map<String, Map<String, bool>>.from(_sessionUnseen.value);
    final projectSessions = Map<String, bool>.from(sessions[projectId] ?? const {});
    projectSessions[sessionId] = unseen;
    sessions[projectId] = projectSessions;
    _sessionUnseen.add(sessions);
  }

  void emitProjectUnseen(Map<String, bool> unseen) => _projectUnseen.add(unseen);

  void emitSessionUnseen(Map<String, Map<String, bool>> unseen) => _sessionUnseen.add(unseen);
}

class MockProjectService extends Mock implements ProjectService {}

class MockProjectApi extends Mock implements ProjectApi {}

class MockProjectRepository extends Mock implements ProjectRepository {}

class MockSessionApi extends Mock implements SessionApi {}

class MockSessionService extends Mock implements SessionService {}

class MockSessionRepository extends Mock implements SessionRepository {}

class MockBridgeRepository extends Mock implements BridgeRepository {}

class MockRegisteredBridgesStore extends Mock implements RegisteredBridgesStore {}

class MockRegisteredBridgesService extends Mock implements RegisteredBridgesService {}

class MockFailureReporter extends Mock implements FailureReporter {}

class MockConnectionService extends Mock implements ConnectionService {
  final StreamController<void> _dataMayBeStale = StreamController<void>.broadcast();

  @override
  Stream<void> get dataMayBeStale => _dataMayBeStale.stream;

  void emitDataMayBeStale() => _dataMayBeStale.add(null);
}

class MockRouteSource extends Mock implements RouteSource {
  final BehaviorSubject<AppRouteDef?> _currentRoute;

  MockRouteSource({AppRouteDef? initialRoute}) : _currentRoute = BehaviorSubject.seeded(initialRoute);

  @override
  ValueStream<AppRouteDef?> get currentRouteStream => _currentRoute.stream;

  AppRouteDef? get currentRoute => _currentRoute.value;

  void emitRoute(AppRouteDef? route) => _currentRoute.add(route);
}

class MockSseEventTracker extends Mock implements SseEventTracker {
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

class FakeUri extends Fake implements Uri {}

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
    () => repository.getMessages(sessionId: any(named: "sessionId")),
  ).thenAnswer(
    (invocation) => service.getMessages(sessionId: invocation.namedArguments[#sessionId]! as String),
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
    () => repository.getChildren(sessionId: any(named: "sessionId")),
  ).thenAnswer(
    (invocation) => service.getChildren(sessionId: invocation.namedArguments[#sessionId]! as String),
  );
  when(() => repository.getSessionStatuses()).thenAnswer((_) => service.getSessionStatuses());
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
      sessionId: any(named: "sessionId"),
      text: any(named: "text"),
      agent: any(named: "agent"),
      model: any(named: "model"),
      variant: any(named: "variant"),
      command: any(named: "command"),
    ),
  ).thenAnswer(
    (invocation) => service.sendMessage(
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

Session testSession({
  String? id,
  String? title,
  DateTime? archivedAt,
  bool unseen = false,
  String pluginId = "plugin-1",
}) {
  return Session(
    id: id ?? "session-1",
    pluginId: pluginId,
    projectID: "project-1",
    directory: "/home/user/my-project",
    parentID: null,
    title: title,
    summary: null,
    pullRequest: null,
    time: SessionTime(
      created: 1700000000000,
      updated: 1700000000000,
      archived: archivedAt?.millisecondsSinceEpoch,
    ),
    promptDefaults: null,
    unseen: unseen,
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
