import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/repositories/derived_project_builder.dart";
import "package:sesori_bridge/src/bridge/repositories/project_repository.dart";
import "package:sesori_bridge/src/bridge/routing/rename_project_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("RenameProjectHandler", () {
    late FakeBridgePlugin plugin;
    late AppDatabase db;
    late RenameProjectHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      db = createTestDatabase();
      handler = RenameProjectHandler(
        ProjectRepository(
          plugin: plugin,
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
          trackingMode: ProjectTrackingMode.nativeBackend,
          derivedProjectBuilder: const DerivedProjectBuilder(),
        ),
      );
    });

    tearDown(() async {
      await plugin.close();
      await db.close();
    });

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

    test("extracts projectId and name from typed body", () async {
      plugin.renameProjectResult = const PluginProject(
        id: "p1",
        name: "New Name",
        time: null,
      );

      await handler.handle(
        makeRequest("PATCH", "/project/name"),
        body: const RenameProjectRequest(projectId: "p1", name: "New Name"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastRenameProjectId, equals("p1"));
      expect(plugin.lastRenameProjectName, equals("New Name"));
    });

    test("returns mapped Project", () async {
      plugin.renameProjectResult = const PluginProject(
        id: "p1",
        name: "Renamed Project",
        time: PluginProjectTime(created: 10, updated: 20),
      );

      final result = await handler.handle(
        makeRequest("PATCH", "/project/name"),
        body: const RenameProjectRequest(projectId: "p1", name: "Renamed Project"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.id, equals("p1"));
      expect(result.name, equals("Renamed Project"));
      expect(result.time?.created, equals(10));
      expect(result.time?.updated, equals(20));
    });
  });
}
