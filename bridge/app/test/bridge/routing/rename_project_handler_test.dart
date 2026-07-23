import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/routing/rename_project_handler.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fake_filesystem_api.dart";
import "../../helpers/fake_git_cli_api.dart";
import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("RenameProjectHandler", () {
    late AppDatabase db;
    late RenameProjectHandler handler;

    setUp(() async {
      db = createTestDatabase();
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
      await db.projectsDao.setActivity(projectId: "p1", createdAt: 101, updatedAt: 202);
      handler = RenameProjectHandler(
        singlePluginProjectRepository(
          gitCliApi: FakeGitCliApi(),
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
          unseenCalculator: const SessionUnseenCalculator(),
          filesystemApi: FakeFilesystemApi(),
        ),
      );
    });

    tearDown(() async {
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

    test("persists the typed bridge-owned project rename without a plugin", () async {
      await handler.handle(
        makeRequest("PATCH", "/project/name"),
        body: const RenameProjectRequest(projectId: "p1", name: "New Name"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect((await db.projectsDao.getProject(projectId: "p1"))?.displayName, "New Name");
    });

    test("returns mapped Project", () async {
      final result = await handler.handle(
        makeRequest("PATCH", "/project/name"),
        body: const RenameProjectRequest(projectId: "p1", name: "Renamed Project"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.id, equals("p1"));
      expect(result.name, equals("Renamed Project"));
      expect(result.time?.created, equals(101));
      expect(result.time?.updated, equals(202));
    });
  });
}
