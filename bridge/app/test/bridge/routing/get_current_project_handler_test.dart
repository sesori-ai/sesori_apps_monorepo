import "dart:convert";

import "package:sesori_bridge/src/bridge/routing/get_current_project_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("GetCurrentProjectHandler", () {
    late FakeBridgePlugin plugin;
    late GetCurrentProjectHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      handler = GetCurrentProjectHandler(plugin);
    });

    tearDown(() => plugin.close());

    test("canHandle GET /project/current", () {
      expect(handler.canHandle(makeRequest("GET", "/project/current")), isTrue);
    });

    test("does not handle GET /project", () {
      expect(handler.canHandle(makeRequest("GET", "/project")), isFalse);
    });

    test("returns 400 without x-opencode-directory header", () async {
      final response = await handler.handle(
        makeRequest("GET", "/project/current"),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("x-opencode-directory"));
    });

    test("returns JSON", () async {
      final response = await handler.handle(
        makeRequest(
          "GET",
          "/project/current",
          headers: {"x-opencode-directory": "/tmp/project"},
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(response.headers["content-type"], equals("application/json"));
      expect(jsonDecode(response.body!), isA<Map<String, dynamic>>());
    });

    test("maps fields", () async {
      plugin.currentProjectResult = const PluginProject(
        id: "p1",
        worktree: "/tmp/project",
        name: "My Project",
        time: PluginProjectTime(created: 11, updated: 22),
      );

      final response = await handler.handle(
        makeRequest(
          "GET",
          "/project/current",
          headers: {"x-opencode-directory": "/tmp/project"},
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(plugin.lastGetCurrentProjectWorktree, equals("/tmp/project"));

      final project = jsonDecode(response.body!) as Map<String, dynamic>;
      expect(project["id"], equals("p1"));
      expect(project["worktree"], equals("/tmp/project"));
      expect(project["name"], equals("My Project"));

      final time = project["time"] as Map<String, dynamic>;
      expect(time["created"], equals(11));
      expect(time["updated"], equals(22));
    });
  });
}
