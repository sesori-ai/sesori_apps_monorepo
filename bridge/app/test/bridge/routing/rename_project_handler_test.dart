import "dart:convert";

import "package:sesori_bridge/src/bridge/routing/rename_project_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("RenameProjectHandler", () {
    late FakeBridgePlugin plugin;
    late RenameProjectHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      handler = RenameProjectHandler(plugin);
    });

    tearDown(() => plugin.close());

    test("canHandle PATCH /project/name", () {
      expect(handler.canHandle(makeRequest("PATCH", "/project/name")), isTrue);
    });

    test("does not handle GET /project/name", () {
      expect(handler.canHandle(makeRequest("GET", "/project/name")), isFalse);
    });

    test("does not handle PATCH /project/:id/name", () {
      expect(handler.canHandle(makeRequest("PATCH", "/project/p1/name")), isFalse);
    });

    test("does not handle PATCH /project/:id", () {
      expect(handler.canHandle(makeRequest("PATCH", "/project/p1")), isFalse);
    });

    test("extracts projectId and parses name from body", () async {
      plugin.renameProjectResult = const PluginProject(
        id: "p1",
        name: "New Name",
        time: null,
      );

      await handler.handle(
        makeRequest(
          "PATCH",
          "/project/name",
          body: jsonEncode(const RenameProjectRequest(projectId: "p1", name: "New Name").toJson()),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(plugin.lastRenameProjectId, equals("p1"));
      expect(plugin.lastRenameProjectName, equals("New Name"));
    });

    test("returns 400 when body has no name key", () async {
      final response = await handler.handle(
        makeRequest("PATCH", "/project/name", body: "{}"),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("invalid JSON body"));
    });

    test("returns 400 when body has no projectId key", () async {
      final response = await handler.handle(
        makeRequest(
          "PATCH",
          "/project/name",
          body: jsonEncode({"name": "New Name"}),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("invalid JSON body"));
    });

    test("returns 200 with mapped Project JSON", () async {
      plugin.renameProjectResult = const PluginProject(
        id: "p1",
        name: "Renamed Project",
        time: PluginProjectTime(created: 10, updated: 20),
      );

      final response = await handler.handle(
        makeRequest(
          "PATCH",
          "/project/name",
          body: jsonEncode(const RenameProjectRequest(projectId: "p1", name: "Renamed Project").toJson()),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(response.headers["content-type"], equals("application/json"));
      final project = jsonDecode(response.body!) as Map<String, dynamic>;
      expect(project["id"], equals("p1"));
      expect(project["name"], equals("Renamed Project"));
    });

    test("returns 400 on malformed body", () async {
      final response = await handler.handle(
        makeRequest("PATCH", "/project/name", body: "not-json"),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
    });
  });
}
