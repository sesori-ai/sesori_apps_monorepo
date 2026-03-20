import "dart:convert";

import "package:sesori_bridge/src/bridge/routing/create_session_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("CreateSessionHandler", () {
    late FakeBridgePlugin plugin;
    late CreateSessionHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      handler = CreateSessionHandler(plugin);
    });

    tearDown(() => plugin.close());

    test("canHandle POST /session", () {
      expect(handler.canHandle(makeRequest("POST", "/session")), isTrue);
    });

    test("does not handle GET /session", () {
      expect(handler.canHandle(makeRequest("GET", "/session")), isFalse);
    });

    test("returns 400 when x-opencode-directory header is missing", () async {
      final response = await handler.handle(
        makeRequest("POST", "/session"),
        pathParams: {},
        queryParams: {},
      );
      expect(response.status, equals(400));
      expect(response.body, contains("x-opencode-directory"));
    });

    test("returns 200 with JSON body", () async {
      plugin.createSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/tmp",
        parentID: null,
        title: "Created",
        time: null,
        summary: null,
      );

      final response = await handler.handle(
        makeRequest("POST", "/session", headers: {"x-opencode-directory": "/tmp"}),
        pathParams: {},
        queryParams: {},
      );

      expect(plugin.lastCreateSessionWorktree, equals("/tmp"));
      expect(response.status, equals(200));
      expect(response.headers["content-type"], equals("application/json"));
      expect(response.body, isNotNull);
    });

    test("maps PluginSession fields to Session JSON", () async {
      plugin.createSessionResult = const PluginSession(
        id: "s1",
        projectID: "p1",
        directory: "/tmp/project",
        parentID: "parent-1",
        title: "Created Session",
        time: PluginSessionTime(created: 100, updated: 200, archived: null),
        summary: PluginSessionSummary(additions: 7, deletions: 2, files: 3),
      );

      final response = await handler.handle(
        makeRequest("POST", "/session", headers: {"x-opencode-directory": "/tmp/project"}),
        pathParams: {},
        queryParams: {},
      );

      final session = jsonDecode(response.body!) as Map<String, dynamic>;
      expect(session["id"], equals("s1"));
      expect(session["projectID"], equals("p1"));
      expect(session["directory"], equals("/tmp/project"));
      expect(session["parentID"], equals("parent-1"));
      expect(session["title"], equals("Created Session"));

      final time = session["time"] as Map<String, dynamic>;
      expect(time["created"], equals(100));
      expect(time["updated"], equals(200));
      expect(time["archived"], isNull);

      final summary = session["summary"] as Map<String, dynamic>;
      expect(summary["additions"], equals(7));
      expect(summary["deletions"], equals(2));
      expect(summary["files"], equals(3));
    });
  });
}
