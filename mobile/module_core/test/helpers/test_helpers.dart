import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/src/api/project_api.dart";
import "package:sesori_dart_core/src/api/session_api.dart";
import "package:sesori_dart_core/src/capabilities/project/project_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/capabilities/session/session_service.dart";
import "package:sesori_dart_core/src/capabilities/sse/session_activity_info.dart";
import "package:sesori_dart_core/src/capabilities/sse/sse_event_repository.dart";
import "package:sesori_dart_core/src/platform/route_source.dart";
import "package:sesori_dart_core/src/repositories/project_repository.dart";
import "package:sesori_dart_core/src/repositories/session_repository.dart";
import "package:sesori_dart_core/src/routing/app_routes.dart";
import "package:sesori_shared/sesori_shared.dart";

class MockProjectService extends Mock implements ProjectService {}

class MockProjectApi extends Mock implements ProjectApi {}

class MockProjectRepository extends Mock implements ProjectRepository {}

class MockSessionApi extends Mock implements SessionApi {}

class MockSessionService extends Mock implements SessionService {}

class MockSessionRepository extends Mock implements SessionRepository {}

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

class MockSseEventRepository extends Mock implements SseEventRepository {
  final BehaviorSubject<Map<String, int>> _projectActivity = BehaviorSubject.seeded(const {});
  final BehaviorSubject<Map<String, Map<String, SessionActivityInfo>>> _sessionActivity = BehaviorSubject.seeded(
    const {},
  );

  @override
  ValueStream<Map<String, int>> get projectActivity => _projectActivity.stream;

  @override
  Map<String, int> get currentProjectActivity => _projectActivity.value;

  @override
  ValueStream<Map<String, Map<String, SessionActivityInfo>>> get sessionActivity => _sessionActivity.stream;

  @override
  Map<String, Map<String, SessionActivityInfo>> get currentSessionActivity => _sessionActivity.value;

  void emitProjectActivity(Map<String, int> activity) => _projectActivity.add(activity);

  void emitSessionActivity(Map<String, Map<String, SessionActivityInfo>> activity) => _sessionActivity.add(activity);
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
  when(() => repository.rejectQuestion(requestId: any(named: "requestId"))).thenAnswer(
    (invocation) => service.rejectQuestion(requestId: invocation.namedArguments[#requestId]! as String),
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
    () => repository.getChildren(sessionId: any(named: "sessionId")),
  ).thenAnswer(
    (invocation) => service.getChildren(sessionId: invocation.namedArguments[#sessionId]! as String),
  );
  when(() => repository.getSessionStatuses()).thenAnswer((_) => service.getSessionStatuses());
  when(() => repository.listAgents()).thenAnswer((_) => service.listAgents());
  when(() => repository.listProviders()).thenAnswer((_) => service.listProviders());
  when(() => repository.listCommands(projectId: any(named: "projectId"))).thenAnswer(
    (invocation) => service.listCommands(projectId: invocation.namedArguments[#projectId] as String?),
  );
  when(
    () => repository.sendMessage(
      sessionId: any(named: "sessionId"),
      text: any(named: "text"),
      agent: any(named: "agent"),
      model: any(named: "model"),
      command: any(named: "command"),
    ),
  ).thenAnswer(
    (invocation) => service.sendMessage(
      sessionId: invocation.namedArguments[#sessionId]! as String,
      text: invocation.namedArguments[#text]! as String,
      agent: invocation.namedArguments[#agent] as String?,
      providerID: (invocation.namedArguments[#model] as PromptModel?)?.providerID,
      modelID: (invocation.namedArguments[#model] as PromptModel?)?.modelID,
      command: invocation.namedArguments[#command] as String?,
    ),
  );
}

void registerAllFallbackValues() {
  registerFallbackValue(const ServerConnectionConfig(relayHost: "fake.example.com"));
  registerFallbackValue(FakeUri());
  registerFallbackValue(StackTrace.empty);
}

Project testProject({String? id, String? path, String? name}) {
  const projectPathField =
      "work"
      "tree";
  return Project.fromJson({
    "id": id ?? "project-1",
    projectPathField: path ?? "/home/user/my-project",
    "name": name,
    "time": {
      "created": 1700000000000,
      "updated": 1700000000000,
    },
  });
}

Session testSession({String? id, String? title, DateTime? archivedAt}) {
  return Session(
    id: id ?? "session-1",
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
  );
}

HealthResponse testHealthResponse() {
  return const HealthResponse(healthy: true, version: "0.1.200", serverManaged: false, serverState: null);
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
