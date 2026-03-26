import "dart:convert";

import "package:sesori_bridge/src/bridge/persistence/daos/projects_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/routing/get_projects_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("GetProjectsHandler", () {
    late FakeBridgePlugin plugin;
    late AppDatabase db;
    late ProjectsDao hiddenStore;
    late GetProjectsHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      db = createTestDatabase();
      hiddenStore = db.projectsDao;
      handler = GetProjectsHandler(plugin, hiddenStore);
    });

    tearDown(() async {
      await plugin.close();
      await db.close();
    });

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

    test("maps PluginProject id and name fields", () async {
      plugin.projectsResult = [
        const PluginProject(
          id: "p1",
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
      expect(project["name"], equals("My Project"));
    });

    test("maps PluginProjectTime when present", () async {
      plugin.projectsResult = [
        const PluginProject(
          id: "p1",
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
        const PluginProject(id: "p1"),
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
        const PluginProject(id: "p1"),
        const PluginProject(id: "p2"),
        const PluginProject(id: "p3"),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/project"),
        pathParams: {},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      expect(body.length, equals(3));
    });

    test("filters out hidden project ids", () async {
      plugin.projectsResult = [
        const PluginProject(id: "visible-1"),
        const PluginProject(id: "hidden-1"),
        const PluginProject(id: "visible-2"),
      ];
      await hiddenStore.hideProject(projectId: "hidden-1");

      final response = await handler.handle(
        makeRequest("GET", "/project"),
        pathParams: {},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as List<dynamic>;
      final ids = body.map((item) => (item as Map<String, dynamic>)["id"] as String).toList();

      expect(ids, equals(["visible-1", "visible-2"]));
    });
  });
}
