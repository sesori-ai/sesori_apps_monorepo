import "package:sesori_bridge/src/api/database/daos/projects_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/routing/get_projects_handler.dart";
import "package:sesori_bridge/src/bridge/services/project_activity_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fake_filesystem_api.dart";
import "../../helpers/fake_git_cli_api.dart";
import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("GetProjectsHandler", () {
    late FakeBridgePlugin plugin;
    late AppDatabase db;
    late ProjectsDao projectsDao;
    late GetProjectsHandler handler;
    late ProjectActivityService projectActivityService;

    setUp(() {
      plugin = FakeBridgePlugin();
      db = createTestDatabase();
      projectsDao = db.projectsDao;
      projectActivityService = ProjectActivityService(
        projectRepository: singlePluginProjectRepository(
          gitCliApi: FakeGitCliApi(),
          plugin: plugin,
          projectsDao: projectsDao,
          sessionDao: db.sessionDao,
          unseenCalculator: const SessionUnseenCalculator(),
          filesystemApi: FakeFilesystemApi(),
        ),
        now: () => 1234,
      );
      handler = GetProjectsHandler(
        projectActivityService: projectActivityService,
      );
    });

    tearDown(() async {
      await projectActivityService.dispose();
      await plugin.close();
      await db.close();
    });

    test("canHandle GET /projects", () {
      expect(handler.canHandle(makeRequest("GET", "/projects")), isTrue);
    });

    test("does not handle POST /projects", () {
      expect(handler.canHandle(makeRequest("POST", "/projects")), isFalse);
    });

    test("does not handle GET /session", () {
      expect(handler.canHandle(makeRequest("GET", "/session")), isFalse);
    });

    test("returns typed projects response", () async {
      final response = await handler.handle(
        makeRequest("GET", "/projects"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(response, isA<Projects>());
    });

    test("returns empty list when plugin has no projects", () async {
      final response = await handler.handle(
        makeRequest("GET", "/projects"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(response.data, isEmpty);
      expect(plugin.getProjectsCallCount, 0);
    });

    test("maps stored project id and display name", () async {
      plugin.projectsResult = [
        const PluginProject(
          id: "p1",
          directory: "p1",
          name: "My Project",
        ),
      ];
      await projectsDao.setActivity(projectId: "p1", createdAt: 1, updatedAt: 2);
      await projectsDao.setDisplayName(projectId: "p1", displayName: "My Project", updatedAt: 2);

      final response = await handler.handle(
        makeRequest("GET", "/projects"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final project = response.data[0];
      expect(project.id, equals("p1"));
      expect(project.name, equals("My Project"));
      expect(plugin.getProjectsCallCount, 0);
    });

    test("maps stored project activity", () async {
      plugin.projectsResult = [
        const PluginProject(
          id: "p1",
          directory: "p1",
          activity: PluginProjectActivity(createdAt: 1000, updatedAt: 2000),
        ),
      ];
      await projectsDao.setActivity(projectId: "p1", createdAt: 1000, updatedAt: 2000);

      final response = await handler.handle(
        makeRequest("GET", "/projects"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final time = response.data[0].time;
      expect(time?.created, equals(1000));
      expect(time?.updated, equals(2000));
    });

    test("time uses the persisted insertion timestamp", () async {
      plugin.projectsResult = [
        const PluginProject(id: "p1", directory: "p1"),
      ];
      await projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);

      final response = await handler.handle(
        makeRequest("GET", "/projects"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final row = await projectsDao.getProject(projectId: "p1");
      expect(response.data[0].time, ProjectTime(created: row!.createdAt, updated: row.updatedAt));
    });

    test("returns all stored projects", () async {
      plugin.projectsResult = [
        const PluginProject(id: "p1", directory: "p1"),
        const PluginProject(id: "p2", directory: "p2"),
        const PluginProject(id: "p3", directory: "p3"),
      ];
      for (final id in ["p1", "p2", "p3"]) {
        await projectsDao.setActivity(projectId: id, createdAt: 1, updatedAt: 1);
      }

      final response = await handler.handle(
        makeRequest("GET", "/projects"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.data.length, equals(3));
      expect(plugin.getProjectsCallCount, 0);
    });

    test("filters out hidden project ids", () async {
      plugin.projectsResult = [
        const PluginProject(id: "visible-1", directory: "visible-1"),
        const PluginProject(id: "hidden-1", directory: "hidden-1"),
        const PluginProject(id: "visible-2", directory: "visible-2"),
      ];
      for (final id in ["visible-1", "hidden-1", "visible-2"]) {
        await projectsDao.setActivity(projectId: id, createdAt: 1, updatedAt: 1);
      }
      await projectsDao.hideProject(projectId: "hidden-1");

      final response = await handler.handle(
        makeRequest("GET", "/projects"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final ids = response.data.map((item) => item.id).toList();

      expect(ids, hasLength(2));
      expect(ids, containsAll(["visible-1", "visible-2"]));
      expect(plugin.getProjectsCallCount, 0);
    });
  });
}
