import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/repositories/project_repository.dart";
import "package:sesori_bridge/src/bridge/routing/hide_project_handler.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("HideProjectHandler", () {
    late AppDatabase db;
    late FakeBridgePlugin plugin;
    late ProjectRepository projectRepository;
    late HideProjectHandler handler;

    setUp(() {
      db = createTestDatabase();
      plugin = FakeBridgePlugin();
      projectRepository = ProjectRepository(
        plugin: plugin,
        projectsDao: db.projectsDao,
      );
      handler = HideProjectHandler(projectRepository: projectRepository);
    });

    tearDown(() async {
      await plugin.close();
      await db.close();
    });

    test("canHandle POST /project/hide", () {
      expect(handler.canHandle(makeRequest("POST", "/project/hide")), isTrue);
    });

    test("does not match DELETE /project/:id", () {
      expect(handler.canHandle(makeRequest("DELETE", "/project/p1")), isFalse);
    });

    test("returns 200 and stores hidden project id", () async {
      final response = await handler.handle(
        makeRequest("POST", "/project/hide"),
        body: const ProjectIdRequest(projectId: "p1"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final hiddenIds = await db.projectsDao.getHiddenProjectIds();
      expect(response, equals(const SuccessEmptyResponse()));
      expect(hiddenIds, contains("p1"));
    });

    test("rejects empty project id", () async {
      expect(
        () => handler.handle(
          makeRequest("POST", "/project/hide"),
          body: const ProjectIdRequest(projectId: ""),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", 400)),
      );
    });

    test("handles project IDs containing slashes", () async {
      const projectId = "/Users/alex/projects/my-app";
      final response = await handler.handle(
        makeRequest("POST", "/project/hide"),
        body: const ProjectIdRequest(projectId: projectId),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final hiddenIds = await db.projectsDao.getHiddenProjectIds();
      expect(response, equals(const SuccessEmptyResponse()));
      expect(hiddenIds, contains(projectId));
    });
  });
}
