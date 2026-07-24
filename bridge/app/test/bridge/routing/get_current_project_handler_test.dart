import "dart:convert";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/routing/get_current_project_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fake_filesystem_api.dart";
import "../../helpers/fake_git_cli_api.dart";
import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("GetCurrentProjectHandler", () {
    late FakeBridgePlugin plugin;
    late AppDatabase db;
    late GetCurrentProjectHandler handler;

    setUp(() async {
      plugin = FakeBridgePlugin();
      db = createTestDatabase();
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/tmp/project"]);
      await db.projectsDao.setActivity(projectId: "/tmp/project", createdAt: 101, updatedAt: 202);
      handler = GetCurrentProjectHandler(
        projectRepository: singlePluginProjectRepository(
          gitCliApi: FakeGitCliApi(),
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
          unseenCalculator: const SessionUnseenCalculator(),
          filesystemApi: FakeFilesystemApi(),
        ),
      );
    });

    tearDown(() async {
      await plugin.close();
      await db.close();
    });

    test("canHandle POST /project/current", () {
      expect(handler.canHandle(makeRequest("POST", "/project/current")), isTrue);
    });

    test("does not handle GET /project/current", () {
      expect(handler.canHandle(makeRequest("GET", "/project/current")), isFalse);
    });

    test("does not handle POST /project", () {
      expect(handler.canHandle(makeRequest("POST", "/project")), isFalse);
    });

    test("rejects empty project id", () async {
      expect(
        () => handler.handle(
          makeRequest("POST", "/project/current"),
          body: const ProjectIdRequest(projectId: ""),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", 400)),
      );
    });

    test("returns typed project", () async {
      final response = await handler.handle(
        makeRequest("POST", "/project/current"),
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
        directory: "/tmp/project",
        name: "My Project",
        activity: PluginProjectActivity(createdAt: 11, updatedAt: 22),
      );
      await db.projectsDao.setDisplayName(
        projectId: "/tmp/project",
        displayName: "My Project",
        updatedAt: 202,
      );

      final response = await handler.handle(
        makeRequest("POST", "/project/current"),
        body: const ProjectIdRequest(projectId: "/tmp/project"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastGetCurrentProjectProjectId, isNull);

      expect(response.id, equals("/tmp/project"));
      expect(response.name, equals("My Project"));
      expect(response.time?.created, equals(101));
      expect(response.time?.updated, equals(202));
    });

    test("returns 404 for an unknown project id without creating a row", () async {
      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/project/current",
          body: jsonEncode(const ProjectIdRequest(projectId: "/unknown").toJson()),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(404));
      expect(await db.projectsDao.getProject(projectId: "/unknown"), isNull);
      expect(plugin.lastGetCurrentProjectProjectId, isNot(equals("/unknown")));
    });
  });
}
