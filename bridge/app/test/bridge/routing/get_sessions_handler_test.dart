import "package:sesori_bridge/src/bridge/persistence/tables/session_table.dart";
import "package:sesori_bridge/src/bridge/routing/get_sessions_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
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

    test("canHandle POST /sessions", () {
      expect(handler.canHandle(makeRequest("POST", "/sessions")), isTrue);
    });

    test("does not handle GET /sessions", () {
      expect(handler.canHandle(makeRequest("GET", "/sessions")), isFalse);
    });

    test("does not handle GET /session/:id/message", () {
      expect(handler.canHandle(makeRequest("GET", "/session/abc/message")), isFalse);
    });

    test("throws 400 when projectId is empty", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/sessions"),
          body: const SessionListRequest(projectId: "", start: null, limit: null),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    test("forwards projectId to plugin.getSessions", () async {
      await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/home/user/proj", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(plugin.lastGetSessionsWorktree, equals("/home/user/proj"));
    });

    test("forwards start and limit from body as ints", () async {
      await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: 5, limit: 20),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(plugin.lastGetSessionsStart, equals(5));
      expect(plugin.lastGetSessionsLimit, equals(20));
    });

    test("start and limit are null when absent from body", () async {
      await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(plugin.lastGetSessionsStart, isNull);
      expect(plugin.lastGetSessionsLimit, isNull);
    });

    test("returns typed SessionListResponse", () async {
      final result = await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(result, isA<SessionListResponse>());
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

      final result = await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final session = result.items.first;
      expect(session.id, equals("s1"));
      expect(session.projectID, equals("p1"));
      expect(session.directory, equals("/tmp"));
      expect(session.title, equals("My session"));
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

      final result = await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final time = result.items.first.time;
      expect(time?.created, equals(100));
      expect(time?.updated, equals(200));
      expect(time?.archived, isNull);
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

      final result = await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final summary = result.items.first.summary;
      expect(summary?.additions, equals(10));
      expect(summary?.deletions, equals(3));
      expect(summary?.files, equals(2));
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

      final result = await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final session = result.items.first;
      expect(session.time, isNull);
      expect(session.summary, isNull);
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

      final result = await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final time = result.items.first.time;
      expect(time?.created, equals(100));
      expect(time?.updated, equals(200));
      expect(time?.archived, equals(999));
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

      final result = await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final time = result.items.first.time;
      expect(time?.created, equals(100));
      expect(time?.updated, equals(200));
      expect(time?.archived, equals(300));
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

      final result = await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final time = result.items.first.time;
      expect(time?.created, equals(100));
      expect(time?.updated, equals(200));
      expect(time?.archived, isNull);
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

      final result = await handler.handle(
        makeRequest("POST", "/sessions"),
        body: const SessionListRequest(projectId: "/tmp", start: null, limit: null),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.items.length, equals(3));
      expect(result.items[0].time?.archived, equals(999));
      expect(result.items[1].time?.archived, isNull);
      expect(result.items[2].time?.archived, equals(500));
    });
  });
}
