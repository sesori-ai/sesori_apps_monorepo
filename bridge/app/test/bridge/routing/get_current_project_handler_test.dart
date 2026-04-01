import "package:sesori_bridge/src/bridge/routing/get_current_project_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
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

    test("returns typed project", () async {
      final response = await handler.handle(
        makeRequest("GET", "/project/current"),
        body: const ProjectIdRequest(projectId: "/tmp/project"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, isA<Project>());
    });

    test("maps fields", () async {
      plugin.currentProjectResult = const PluginProject(
        id: "p1",
        name: "My Project",
        time: PluginProjectTime(created: 11, updated: 22),
      );

      final response = await handler.handle(
        makeRequest("GET", "/project/current"),
        body: const ProjectIdRequest(projectId: "/tmp/project"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastGetCurrentProjectProjectId, equals("/tmp/project"));

      expect(response.id, equals("p1"));
      expect(response.name, equals("My Project"));
      expect(response.time?.created, equals(11));
      expect(response.time?.updated, equals(22));
    });
  });
}
