import "dart:async";
import "dart:convert";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/routing/get_child_sessions_handler.dart";
import "package:sesori_bridge/src/routing/get_session_handler.dart";
import "package:sesori_bridge/src/routing/get_sessions_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/session_continuation_test_support.dart";
import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("catalog read handlers", () {
    late AppDatabase database;
    late _NeverCompletingPlugin plugin;
    late SessionRepository repository;

    setUp(() async {
      database = createTestDatabase();
      plugin = _NeverCompletingPlugin();
      repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: database.sessionDao,
        projectsDao: database.projectsDao,
        pullRequestDao: database.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      await database.projectsDao.recordOpenedProject(
        projectId: "project",
        path: "/projects/project",
        displayName: null,
        createdAt: 1,
        updatedAt: 1,
      );
      await database.sessionDao.insertSession(
        fastMode: false,
        sessionId: "root",
        backendSessionId: "backend-root",
        projectId: "project",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
        pluginId: "offline-plugin",
        preservePullRequestScope: false,
      );
      await database.sessionDao.insertObservedChild(
        sessionId: "child",
        backendSessionId: "backend-child",
        projectId: "project",
        parentSessionId: "root",
        directory: "/projects/project/child",
        catalogTitle: "Child",
        archivedAt: null,
        createdAt: 2,
        updatedAt: 2,
        projectionUpdatedAt: 2,
        pluginId: "offline-plugin",
      );
    });

    tearDown(() async {
      await repository.dispose();
      await database.close();
    });

    test("root list, detail, and children complete without plugin calls", () async {
      final sessionsHandler = GetSessionsHandler(
        sessionViews: const PassThroughSessionViews(),
        sessionRepository: repository,
      );
      final detailHandler = GetSessionHandler(
        sessionViews: const PassThroughSessionViews(),
        sessionRepository: repository,
      );
      final childrenHandler = GetChildSessionsHandler(
        sessionViews: const PassThroughSessionViews(),
        sessionRepository: repository,
      );

      final roots = await sessionsHandler
          .handle(
            makeRequest("POST", "/sessions"),
            body: const SessionListRequest(projectId: "project", start: null, limit: null),
          )
          .timeout(const Duration(seconds: 1));
      final detail = await detailHandler
          .handle(
            makeRequest("POST", "/session/detail"),
            body: const SessionIdRequest(sessionId: "root"),
          )
          .timeout(const Duration(seconds: 1));
      final children = await childrenHandler
          .handle(
            makeRequest("POST", "/session/children"),
            body: const SessionIdRequest(sessionId: "root"),
          )
          .timeout(const Duration(seconds: 1));

      expect(roots.items.single.id, "root");
      expect(detail.id, "root");
      expect(children.items.single.id, "child");
      expect(plugin.calls, 0);
    });

    test("unknown detail and parent ids remain 404s without plugin calls", () async {
      final detailHandler = GetSessionHandler(
        sessionViews: const PassThroughSessionViews(),
        sessionRepository: repository,
      );
      final childrenHandler = GetChildSessionsHandler(
        sessionViews: const PassThroughSessionViews(),
        sessionRepository: repository,
      );

      final detail = await detailHandler.routeForTest(
        makeRequest(
          "POST",
          "/session/detail",
          body: jsonEncode(const SessionIdRequest(sessionId: "missing").toJson()),
        ),
      );
      final children = await childrenHandler.routeForTest(
        makeRequest(
          "POST",
          "/session/children",
          body: jsonEncode(const SessionIdRequest(sessionId: "missing").toJson()),
        ),
      );

      expect(detail.status, 404);
      expect(children.status, 404);
      expect(plugin.calls, 0);
    });
  });
}

class _NeverCompletingPlugin() implements NativeProjectsPluginApi {
  int calls = 0;

  @override
  String get id => "running-plugin";

  @override
  Future<List<PluginProject>> getProjects() {
    calls++;
    return Completer<List<PluginProject>>().future;
  }

  @override
  Future<PluginProject> getProject(String projectId) {
    calls++;
    return Completer<PluginProject>().future;
  }

  @override
  Future<List<PluginSession>> getSessions({required String projectId, required int? start, required int? limit}) {
    calls++;
    return Completer<List<PluginSession>>().future;
  }

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) {
    calls++;
    return Completer<List<PluginSession>>().future;
  }

  @override
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    throw StateError("catalog handler unexpectedly called plugin member ${invocation.memberName}");
  }
}
