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

    test("canHandle POST /session/children", () {
      expect(handler.canHandle(makeRequest("POST", "/session/children")), isTrue);
    });

    test("does not handle GET /session/children", () {
      expect(handler.canHandle(makeRequest("GET", "/session/children")), isFalse);
    });

    test("extracts sessionId from body", () async {
      await handler.handleInternal(
        makeRequest("POST", "/session/children", body: jsonEncode({"sessionId": "s1"})),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastGetChildSessionsSessionId, equals("s1"));
    });

    test("returns 400 when session id is empty", () async {
      final response = await handler.handleInternal(
        makeRequest("POST", "/session/children", body: jsonEncode({"sessionId": ""})),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(400));
      expect(response.body, contains("empty session id"));
    });

    test("returns JSON wrapper", () async {
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

      final response = await handler.handleInternal(
        makeRequest("POST", "/session/children", body: jsonEncode({"sessionId": "s1"})),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(200));
      expect(response.headers["content-type"], equals("application/json"));
      final json = jsonDecode(response.body!) as Map<String, dynamic>;
      final body = json["items"] as List<dynamic>;
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

      final response = await handler.handleInternal(
        makeRequest("POST", "/session/children", body: jsonEncode({"sessionId": "parent-1"})),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final json = jsonDecode(response.body!) as Map<String, dynamic>;
      final body = json["items"] as List<dynamic>;
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
