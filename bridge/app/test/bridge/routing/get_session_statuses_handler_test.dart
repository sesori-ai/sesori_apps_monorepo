import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/routing/get_session_statuses_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("GetSessionStatusesHandler", () {
    late FakeBridgePlugin plugin;
    late AppDatabase db;
    late GetSessionStatusesHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      db = createTestDatabase();
      handler = GetSessionStatusesHandler(
        sessionRepository: singlePluginSessionRepository(
          plugin: plugin,
          sessionDao: db.sessionDao,
          projectsDao: db.projectsDao,
          pullRequestDao: db.pullRequestDao,
          unseenCalculator: const SessionUnseenCalculator(),
        ),
      );
    });

    tearDown(() async {
      await plugin.close();
      await db.close();
    });

    test("canHandle GET /session/status", () {
      expect(handler.canHandle(makeRequest("GET", "/session/status")), isTrue);
    });

    test("does not handle GET /session", () {
      expect(handler.canHandle(makeRequest("GET", "/session")), isFalse);
    });

    test("exposes only bound stable root session IDs", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["project"]);
      await db.sessionDao.insertSession(
        sessionId: "stable-root",
        backendSessionId: "backend-root",
        pluginId: plugin.id,
        projectId: "project",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
      );
      plugin.sessionStatusesResult = {
        "backend-root": const PluginSessionStatus.idle(),
        "unbound-backend": const PluginSessionStatus.busy(),
      };

      final response = await handler.handle(
        makeRequest("GET", "/session/status"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.statuses, equals({"stable-root": const SessionStatus.idle()}));
    });

    test("maps idle, busy, and retry correctly", () async {
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["project"]);
      for (final id in ["idle-session", "busy-session", "retry-session"]) {
        await db.sessionDao.insertSession(
          sessionId: "stable-$id",
          backendSessionId: id,
          pluginId: plugin.id,
          projectId: "project",
          isDedicated: false,
          createdAt: 1,
          worktreePath: null,
          branchName: null,
          baseBranch: null,
          baseCommit: null,
          lastAgent: null,
          lastAgentModel: null,
        );
      }
      plugin.sessionStatusesResult = {
        "idle-session": const PluginSessionStatus.idle(),
        "busy-session": const PluginSessionStatus.busy(),
        "retry-session": const PluginSessionStatus.retry(
          attempt: 2,
          message: "Rate limited",
          next: 123456,
        ),
      };

      final response = await handler.handle(
        makeRequest("GET", "/session/status"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.statuses["stable-idle-session"], equals(const SessionStatus.idle()));
      expect(response.statuses["stable-busy-session"], equals(const SessionStatus.busy()));
      expect(
        response.statuses["stable-retry-session"],
        equals(const SessionStatus.retry(attempt: 2, message: "Rate limited", next: 123456)),
      );
    });
  });
}
