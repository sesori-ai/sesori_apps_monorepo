import "package:sesori_bridge/src/bridge/routing/get_child_sessions_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("GetChildSessionsHandler", () {
    late FakeBridgePlugin plugin;
    late FakeSessionRepository sessionRepository;
    late GetChildSessionsHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      sessionRepository = FakeSessionRepository(plugin: plugin);
      handler = GetChildSessionsHandler(sessionRepository: sessionRepository);
    });

    tearDown(() => plugin.close());

    test("canHandle POST /session/children", () {
      expect(handler.canHandle(makeRequest("POST", "/session/children")), isTrue);
    });

    test("does not handle GET /session/children", () {
      expect(handler.canHandle(makeRequest("GET", "/session/children")), isFalse);
    });

    test("extracts sessionId from body", () async {
      await handler.handle(
        makeRequest("POST", "/session/children"),
        body: const SessionIdRequest(sessionId: "s1"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastGetChildSessionsSessionId, equals("s1"));
    });

    test("returns 400 when session id is empty", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/session/children"),
          body: const SessionIdRequest(sessionId: ""),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    test("returns typed response", () async {
      plugin.childSessionsResult = const [
        PluginSession(
          branchName: null,
          id: "c1",
          projectID: "p1",
          directory: "/tmp",
          parentID: "s1",
          title: "child",
          time: null,
        ),
      ];

      final response = await handler.handle(
        makeRequest("POST", "/session/children"),
        body: const SessionIdRequest(sessionId: "s1"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.items, hasLength(1));
    });

    test("maps correctly", () async {
      plugin.childSessionsResult = const [
        PluginSession(
          branchName: null,
          id: "child-1",
          projectID: "project-1",
          directory: "/tmp/project",
          parentID: "parent-1",
          title: "Child Session",
          time: PluginSessionTime(created: 10, updated: 20, archived: null),
        ),
      ];

      final response = await handler.handle(
        makeRequest("POST", "/session/children"),
        body: const SessionIdRequest(sessionId: "parent-1"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final session = response.items[0];
      expect(session.id, equals("child-1"));
      expect(session.projectID, equals("project-1"));
      expect(session.directory, equals("/tmp/project"));
      expect(session.parentID, equals("parent-1"));
      expect(session.title, equals("Child Session"));
      expect(session.time?.created, equals(10));
      expect(session.time?.updated, equals(20));
      expect(session.time?.archived, isNull);
    });

    test("keeps pullRequest null for child sessions", () async {
      plugin.childSessionsResult = const [
        PluginSession(
          branchName: null,
          id: "child-1",
          projectID: "project-1",
          directory: "/tmp/project",
          parentID: "parent-1",
          title: "Child Session",
          time: null,
        ),
      ];

      final response = await handler.handle(
        makeRequest("POST", "/session/children"),
        body: const SessionIdRequest(sessionId: "parent-1"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.items.single.pullRequest, isNull);
    });
  });
}
