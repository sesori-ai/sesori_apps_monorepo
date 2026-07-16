import "package:sesori_bridge/src/api/database/daos/projects_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/repositories/project_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/routing/get_projects_handler.dart";
import "package:sesori_bridge/src/bridge/services/project_activity_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fake_filesystem_api.dart";
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
        projectRepository: ProjectRepository(
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
    });

    test("maps PluginProject id and name fields", () async {
      plugin.projectsResult = [
        const PluginProject(
          id: "p1",
          directory: "p1",
          name: "My Project",
        ),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/projects"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final project = response.data[0];
      expect(project.id, equals("p1"));
      expect(project.name, equals("My Project"));
    });

    test("maps PluginProjectActivity when present", () async {
      plugin.projectsResult = [
        const PluginProject(
          id: "p1",
          directory: "p1",
          activity: PluginProjectActivity(createdAt: 1000, updatedAt: 2000),
        ),
      ];

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

    test("time uses the persisted insertion timestamp when plugin activity is absent", () async {
      plugin.projectsResult = [
        const PluginProject(id: "p1", directory: "p1"),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/projects"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final row = await projectsDao.getProject(projectId: "p1");
      expect(response.data[0].time, ProjectTime(created: row!.createdAt, updated: row.updatedAt));
    });

    test("returns all projects when plugin returns multiple", () async {
      plugin.projectsResult = [
        const PluginProject(id: "p1", directory: "p1"),
        const PluginProject(id: "p2", directory: "p2"),
        const PluginProject(id: "p3", directory: "p3"),
      ];

      final response = await handler.handle(
        makeRequest("GET", "/projects"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.data.length, equals(3));
    });

    test("filters out hidden project ids", () async {
      plugin.projectsResult = [
        const PluginProject(id: "visible-1", directory: "visible-1"),
        const PluginProject(id: "hidden-1", directory: "hidden-1"),
        const PluginProject(id: "visible-2", directory: "visible-2"),
      ];
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
    });
  });
}
