import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/src/capabilities/project/project_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/capabilities/session/session_service.dart";
import "package:sesori_dart_core/src/capabilities/sse/session_activity_info.dart";
import "package:sesori_dart_core/src/capabilities/sse/sse_event_repository.dart";
import "package:sesori_dart_core/src/platform/route_source.dart";
import "package:sesori_dart_core/src/routing/app_routes.dart";
import "package:sesori_shared/sesori_shared.dart";

class MockProjectService extends Mock implements ProjectService {}

class MockSessionService extends Mock implements SessionService {}

class MockFailureReporter extends Mock implements FailureReporter {}

class MockConnectionService extends Mock implements ConnectionService {}

class MockRouteSource extends Mock implements RouteSource {
  final BehaviorSubject<AppRoute?> _currentRoute;

  MockRouteSource({AppRoute? initialRoute}) : _currentRoute = BehaviorSubject.seeded(initialRoute);

  @override
  ValueStream<AppRoute?> get currentRouteStream => _currentRoute.stream;

  AppRoute? get currentRoute => _currentRoute.value;

  void emitRoute(AppRoute? route) => _currentRoute.add(route);
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
    title: title,
    time: SessionTime(
      created: 1700000000000,
      updated: 1700000000000,
      archived: archivedAt?.millisecondsSinceEpoch,
    ),
  );
}

HealthResponse testHealthResponse() {
  return const HealthResponse(healthy: true, version: "0.1.200");
}
