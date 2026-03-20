import "dart:convert";

import "package:sesori_bridge/src/bridge/routing/get_child_sessions_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("GetChildSessionsHandler", () {
    late FakeBridgePlugin plugin;
    late GetChildSessionsHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      handler = GetChildSessionsHandler(plugin);
    });

    tearDown(() => plugin.close());

    test("canHandle GET /session/:id/children", () {
      expect(handler.canHandle(makeRequest("GET", "/session/s1/children")), isTrue);
    });

    test("does not handle GET /session/:id/message", () {
      expect(handler.canHandle(makeRequest("GET", "/session/s1/message")), isFalse);
    });

    test("extracts id", () async {
      await handler.handle(
        makeRequest("GET", "/session/s1/children"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(plugin.lastGetChildSessionsSessionId, equals("s1"));
    });

    test("returns JSON list", () async {
      plugin.childSessionsResult = const [
        PluginSession(
          id: "c1",
          projectID: "p1",
          directory: "/tmp",
          parentID: "s1",
          title: "child",
          time: null,
          summary: null,
        ),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/session/s1/children"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(response.headers["content-type"], equals("application/json"));
      final body = jsonDecode(response.body!) as List<dynamic>;
      expect(body, hasLength(1));
    });

    test("maps correctly", () async {
      plugin.childSessionsResult = const [
        PluginSession(
          id: "child-1",
          projectID: "project-1",
          directory: "/tmp/project",
          parentID: "parent-1",
          title: "Child Session",
          time: PluginSessionTime(created: 10, updated: 20, archived: null),
          summary: PluginSessionSummary(additions: 5, deletions: 2, files: 3),
        ),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/session/parent-1/children"),
        pathParams: {"id": "parent-1"},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      final session = body[0] as Map<String, dynamic>;
      expect(session["id"], equals("child-1"));
      expect(session["projectID"], equals("project-1"));
      expect(session["directory"], equals("/tmp/project"));
      expect(session["parentID"], equals("parent-1"));
      expect(session["title"], equals("Child Session"));

      final time = session["time"] as Map<String, dynamic>;
      expect(time["created"], equals(10));
      expect(time["updated"], equals(20));
      expect(time["archived"], isNull);

      final summary = session["summary"] as Map<String, dynamic>;
      expect(summary["additions"], equals(5));
      expect(summary["deletions"], equals(2));
      expect(summary["files"], equals(3));
    });
  });
}
