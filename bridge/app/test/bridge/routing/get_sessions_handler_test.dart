import "dart:convert";

import "package:sesori_bridge/src/bridge/persistence/tables/session_table.dart";
import "package:sesori_bridge/src/bridge/routing/get_sessions_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("GetSessionsHandler", () {
    late FakeBridgePlugin plugin;
    late FakeSessionDao sessionDao;
    late GetSessionsHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      sessionDao = FakeSessionDao();
      handler = GetSessionsHandler(plugin, sessionDao);
    });

    tearDown(() => plugin.close());

    test("canHandle GET /session", () {
      expect(handler.canHandle(makeRequest("GET", "/session")), isTrue);
    });

    test("does not handle POST /session", () {
      expect(handler.canHandle(makeRequest("POST", "/session")), isFalse);
    });

    test("does not handle GET /session/:id/message", () {
      expect(handler.canHandle(makeRequest("GET", "/session/abc/message")), isFalse);
    });

    test("returns 400 when x-project-id header is missing", () async {
      final response = await handler.handle(
        makeRequest("GET", "/session"),
        pathParams: {},
        queryParams: {},
      );
      expect(response.status, equals(400));
      expect(response.body, contains("x-project-id"));
    });

    test("returns 400 when x-project-id header is empty", () async {
      final response = await handler.handle(
        makeRequest("GET", "/session", headers: {"x-project-id": ""}),
        pathParams: {},
        queryParams: {},
      );
      expect(response.status, equals(400));
    });

    test("accepts x-project-id header", () async {
      final response = await handler.handle(
        makeRequest("GET", "/session", headers: {"x-project-id": "/tmp"}),
        pathParams: {},
        queryParams: {},
      );
      expect(response.status, equals(200));
    });

    test("forwards x-project-id header to plugin.getSessions", () async {
      await handler.handle(
        makeRequest("GET", "/session", headers: {"x-project-id": "/home/user/proj"}),
        pathParams: {},
        queryParams: {},
      );
      expect(plugin.lastGetSessionsWorktree, equals("/home/user/proj"));
    });

    test("forwards start and limit from queryParams as ints", () async {
      await handler.handle(
        makeRequest("GET", "/session", headers: {"x-project-id": "/tmp"}),
        pathParams: {},
        queryParams: {"start": "5", "limit": "20"},
      );
      expect(plugin.lastGetSessionsStart, equals(5));
      expect(plugin.lastGetSessionsLimit, equals(20));
    });

    test("start and limit are null when absent from queryParams", () async {
      await handler.handle(
        makeRequest("GET", "/session", headers: {"x-project-id": "/tmp"}),
        pathParams: {},
        queryParams: {},
      );
      expect(plugin.lastGetSessionsStart, isNull);
      expect(plugin.lastGetSessionsLimit, isNull);
    });

    test("returns 200 with application/json content-type", () async {
      final response = await handler.handle(
        makeRequest("GET", "/session", headers: {"x-project-id": "/tmp"}),
        pathParams: {},
        queryParams: {},
      );
      expect(response.status, equals(200));
      expect(response.headers["content-type"], equals("application/json"));
    });

    test("maps PluginSession id, projectID, directory, and title", () async {
      plugin.sessionsResult = [
        const PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: "My session",
          time: null,
          summary: null,
        ),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/session", headers: {"x-project-id": "/tmp"}),
        pathParams: {},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      final session = body[0] as Map<String, dynamic>;
      expect(session["id"], equals("s1"));
      expect(session["projectID"], equals("p1"));
      expect(session["directory"], equals("/tmp"));
      expect(session["title"], equals("My session"));
    });

    test("maps PluginSessionTime when present", () async {
      plugin.sessionsResult = [
        const PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: null,
          time: PluginSessionTime(created: 100, updated: 200, archived: null),
          summary: null,
        ),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/session", headers: {"x-project-id": "/tmp"}),
        pathParams: {},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      final time = (body[0] as Map<String, dynamic>)["time"] as Map<String, dynamic>;
      expect(time["created"], equals(100));
      expect(time["updated"], equals(200));
      expect(time["archived"], isNull);
    });

    test("maps PluginSessionSummary when present", () async {
      plugin.sessionsResult = [
        const PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: null,
          time: null,
          summary: PluginSessionSummary(additions: 10, deletions: 3, files: 2),
        ),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/session", headers: {"x-project-id": "/tmp"}),
        pathParams: {},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      final summary = (body[0] as Map<String, dynamic>)["summary"] as Map<String, dynamic>;
      expect(summary["additions"], equals(10));
      expect(summary["deletions"], equals(3));
      expect(summary["files"], equals(2));
    });

    test("time and summary are null when absent", () async {
      plugin.sessionsResult = [
        const PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: null,
          time: null,
          summary: null,
        ),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/session", headers: {"x-project-id": "/tmp"}),
        pathParams: {},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      final session = body[0] as Map<String, dynamic>;
      expect(session["time"], isNull);
      expect(session["summary"], isNull);
    });

    test("overrides time.archived with DB archivedAt when present", () async {
      plugin.sessionsResult = [
        const PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: null,
          time: PluginSessionTime(created: 100, updated: 200, archived: 300),
          summary: null,
        ),
      ];

      // Set up DB with different archived time
      sessionDao.setSession(
        const SessionDto(
          sessionId: "s1",
          projectId: "p1",
          worktreePath: null,
          branchName: null,
          isDedicated: false,
          archivedAt: 999,
          baseBranch: null,
          baseCommit: null,
          createdAt: 100,
        ),
      );

      final response = await handler.handle(
        makeRequest("GET", "/session", headers: {"x-project-id": "/tmp"}),
        pathParams: {},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      final time = (body[0] as Map<String, dynamic>)["time"] as Map<String, dynamic>;
      expect(time["created"], equals(100));
      expect(time["updated"], equals(200));
      expect(time["archived"], equals(999)); // DB value overrides plugin value
    });

    test("keeps plugin time.archived when no DB record exists", () async {
      plugin.sessionsResult = [
        const PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: null,
          time: PluginSessionTime(created: 100, updated: 200, archived: 300),
          summary: null,
        ),
      ];

      // No DB record for this session

      final response = await handler.handle(
        makeRequest("GET", "/session", headers: {"x-project-id": "/tmp"}),
        pathParams: {},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      final time = (body[0] as Map<String, dynamic>)["time"] as Map<String, dynamic>;
      expect(time["created"], equals(100));
      expect(time["updated"], equals(200));
      expect(time["archived"], equals(300)); // Plugin value preserved
    });

    test("sets time.archived to null when DB has null archivedAt", () async {
      plugin.sessionsResult = [
        const PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: null,
          time: PluginSessionTime(created: 100, updated: 200, archived: 300),
          summary: null,
        ),
      ];

      // Set up DB with null archived time
      sessionDao.setSession(
        const SessionDto(
          sessionId: "s1",
          projectId: "p1",
          worktreePath: null,
          branchName: null,
          isDedicated: false,
          archivedAt: null,
          baseBranch: null,
          baseCommit: null,
          createdAt: 100,
        ),
      );

      final response = await handler.handle(
        makeRequest("GET", "/session", headers: {"x-project-id": "/tmp"}),
        pathParams: {},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      final time = (body[0] as Map<String, dynamic>)["time"] as Map<String, dynamic>;
      expect(time["created"], equals(100));
      expect(time["updated"], equals(200));
      expect(time["archived"], isNull); // DB null value preserved
    });

    test("handles multiple sessions with mixed DB/plugin archive status", () async {
      plugin.sessionsResult = [
        const PluginSession(
          id: "s1",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: null,
          time: PluginSessionTime(created: 100, updated: 200, archived: 300),
          summary: null,
        ),
        const PluginSession(
          id: "s2",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: null,
          time: PluginSessionTime(created: 100, updated: 200, archived: 400),
          summary: null,
        ),
        const PluginSession(
          id: "s3",
          projectID: "p1",
          directory: "/tmp",
          parentID: null,
          title: null,
          time: PluginSessionTime(created: 100, updated: 200, archived: 500),
          summary: null,
        ),
      ];

      // s1: DB has different archived time
      sessionDao.setSession(
        const SessionDto(
          sessionId: "s1",
          projectId: "p1",
          worktreePath: null,
          branchName: null,
          isDedicated: false,
          archivedAt: 999,
          baseBranch: null,
          baseCommit: null,
          createdAt: 100,
        ),
      );
      // s2: DB has null archived time
      sessionDao.setSession(
        const SessionDto(
          sessionId: "s2",
          projectId: "p1",
          worktreePath: null,
          branchName: null,
          isDedicated: false,
          archivedAt: null,
          baseBranch: null,
          baseCommit: null,
          createdAt: 100,
        ),
      );
      // s3: No DB record

      final response = await handler.handle(
        makeRequest("GET", "/session", headers: {"x-project-id": "/tmp"}),
        pathParams: {},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      expect(body.length, equals(3));

      final time1 = (body[0] as Map<String, dynamic>)["time"] as Map<String, dynamic>;
      expect(time1["archived"], equals(999)); // DB override

      final time2 = (body[1] as Map<String, dynamic>)["time"] as Map<String, dynamic>;
      expect(time2["archived"], isNull); // DB null

      final time3 = (body[2] as Map<String, dynamic>)["time"] as Map<String, dynamic>;
      expect(time3["archived"], equals(500)); // Plugin value
    });
  });
}
