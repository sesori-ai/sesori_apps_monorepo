import "dart:convert";

import "package:sesori_bridge/src/bridge/routing/get_projects_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("GetProjectsHandler", () {
    late FakeBridgePlugin plugin;
    late GetProjectsHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      handler = GetProjectsHandler(plugin);
    });

    tearDown(() => plugin.close());

    test("canHandle GET /project", () {
      expect(handler.canHandle(makeRequest("GET", "/project")), isTrue);
    });

    test("does not handle POST /project", () {
      expect(handler.canHandle(makeRequest("POST", "/project")), isFalse);
    });

    test("does not handle GET /session", () {
      expect(handler.canHandle(makeRequest("GET", "/session")), isFalse);
    });

    test("returns 200 with application/json content-type", () async {
      final response = await handler.handle(
        makeRequest("GET", "/project"),
        pathParams: {},
        queryParams: {},
      );
      expect(response.status, equals(200));
      expect(response.headers["content-type"], equals("application/json"));
    });

    test("returns empty list when plugin has no projects", () async {
      final response = await handler.handle(
        makeRequest("GET", "/project"),
        pathParams: {},
        queryParams: {},
      );
      final body = jsonDecode(response.body!) as List<dynamic>;
      expect(body, isEmpty);
    });

    test("maps PluginProject id, worktree, and name fields", () async {
      plugin.projectsResult = [
        const PluginProject(
          id: "p1",
          worktree: "/home/user/proj",
          name: "My Project",
        ),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/project"),
        pathParams: {},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      final project = body[0] as Map<String, dynamic>;
      expect(project["id"], equals("p1"));
      expect(project["worktree"], equals("/home/user/proj"));
      expect(project["name"], equals("My Project"));
    });

    test("maps PluginProjectTime when present", () async {
      plugin.projectsResult = [
        const PluginProject(
          id: "p1",
          worktree: "/tmp",
          time: PluginProjectTime(created: 1000, updated: 2000),
        ),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/project"),
        pathParams: {},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      final time = (body[0] as Map<String, dynamic>)["time"] as Map<String, dynamic>;
      expect(time["created"], equals(1000));
      expect(time["updated"], equals(2000));
    });

    test("time is null when PluginProjectTime is absent", () async {
      plugin.projectsResult = [
        const PluginProject(id: "p1", worktree: "/tmp"),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/project"),
        pathParams: {},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      expect((body[0] as Map<String, dynamic>)["time"], isNull);
    });

    test("returns all projects when plugin returns multiple", () async {
      plugin.projectsResult = [
        const PluginProject(id: "p1", worktree: "/a"),
        const PluginProject(id: "p2", worktree: "/b"),
        const PluginProject(id: "p3", worktree: "/c"),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/project"),
        pathParams: {},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      expect(body.length, equals(3));
    });
  });
}
