import "dart:io";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/api/filesystem_api.dart";
import "package:sesori_bridge/src/bridge/foundation/filesystem_permission_validator.dart";
import "package:sesori_bridge/src/bridge/repositories/filesystem_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/project_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/routing/open_project_handler.dart";
import "package:sesori_bridge/src/bridge/services/project_activity_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fake_filesystem_api.dart";
import "../../helpers/fake_git_cli_api.dart";
import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("OpenProjectHandler", () {
    late FakeBridgePlugin plugin;
    late AppDatabase db;
    late ProjectRepository projectRepository;
    late ProjectActivityService projectActivityService;
    late OpenProjectHandler handler;
    late Directory tempDir;
    late File tempFile;

    setUp(() {
      plugin = FakeBridgePlugin();
      db = createTestDatabase();
      tempDir = Directory.systemTemp.createTempSync("sesori_discover_test_");
      tempFile = File("${tempDir.path}/test_file.txt")..createSync();
      projectRepository = singlePluginProjectRepository(
        gitCliApi: FakeGitCliApi(),
        plugin: plugin,
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
        filesystemApi: FakeFilesystemApi(),
      );
      projectActivityService = ProjectActivityService(
        projectRepository: projectRepository,
        now: () => 1234,
      );
      handler = OpenProjectHandler(
        filesystemRepository: FilesystemRepository(
          filesystemApi: const FilesystemApi(),
          permissionValidator: const FilesystemPermissionValidator(),
        ),
        projectActivityService: projectActivityService,
      );
    });

    tearDown(() async {
      await projectActivityService.dispose();
      await plugin.close();
      await db.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    // ── Route matching ───────────────────────────────────────────────────────

    test("canHandle POST /project/open", () {
      expect(handler.canHandle(makeRequest("POST", "/project/open")), isTrue);
    });

    test("does not handle GET /project/open", () {
      expect(handler.canHandle(makeRequest("GET", "/project/open")), isFalse);
    });

    test("does not handle POST /project", () {
      expect(handler.canHandle(makeRequest("POST", "/project")), isFalse);
    });

    // ── Path validation ──────────────────────────────────────────────────────

    test("returns 400 when path is empty", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/project/open"),
          body: const ProjectPathRequest(path: ""),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    test("returns 400 when path is relative", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/project/open"),
          body: const ProjectPathRequest(path: "relative/path"),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    test("returns 400 when path contains path traversal (..) segment", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/project/open"),
          body: const ProjectPathRequest(path: "/tmp/../etc"),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    // ── Filesystem validation ────────────────────────────────────────────────

    test("returns 404 when path does not exist", () async {
      final nonExistent = "${tempDir.path}/nonexistent-path-xyz";

      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/project/open"),
          body: ProjectPathRequest(path: nonExistent),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(404))),
      );
    });

    test("returns 400 when path points to a file not a directory", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/project/open"),
          body: ProjectPathRequest(path: tempFile.path),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    // ── Successful discovery ─────────────────────────────────────────────────

    test("calls plugin.getProject with the given path", () async {
      plugin.currentProjectResult = PluginProject(id: tempDir.path, directory: tempDir.path);

      await handler.handle(
        makeRequest("POST", "/project/open"),
        body: ProjectPathRequest(path: tempDir.path),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastGetCurrentProjectProjectId, equals(tempDir.path));
    });

    test("returns 200 with application/json content-type", () async {
      plugin.currentProjectResult = PluginProject(id: tempDir.path, directory: tempDir.path);

      final result = await handler.handle(
        makeRequest("POST", "/project/open"),
        body: ProjectPathRequest(path: tempDir.path),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.id, equals(tempDir.path));
    });

    test("maps project id and name fields", () async {
      plugin.currentProjectResult = PluginProject(
        id: tempDir.path,
        directory: tempDir.path,
        name: "My Project",
      );

      final result = await handler.handle(
        makeRequest("POST", "/project/open"),
        body: ProjectPathRequest(path: tempDir.path),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.id, equals(tempDir.path));
      expect(result.name, equals("My Project"));
    });

    test("maps ProjectTime from the persisted open timestamp", () async {
      plugin.currentProjectResult = PluginProject(
        id: tempDir.path,
        directory: tempDir.path,
        activity: const PluginProjectActivity(createdAt: 1000, updatedAt: 2000),
      );

      final result = await handler.handle(
        makeRequest("POST", "/project/open"),
        body: ProjectPathRequest(path: tempDir.path),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.time, const ProjectTime(created: 1234, updated: 1234));
    });

    test("time is non-null when plugin returns no activity", () async {
      plugin.currentProjectResult = PluginProject(id: tempDir.path, directory: tempDir.path);

      final result = await handler.handle(
        makeRequest("POST", "/project/open"),
        body: ProjectPathRequest(path: tempDir.path),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.time, const ProjectTime(created: 1234, updated: 1234));
    });

    // ── Plugin error propagation ─────────────────────────────────────────────

    test("returns 500 when plugin.getProject() throws", () async {
      plugin.throwOnGetProjectError = PluginApiException("/project/open", 404);

      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/project/open"),
          body: ProjectPathRequest(path: tempDir.path),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<PluginApiException>()),
      );
    });

    // ── Idempotency ──────────────────────────────────────────────────────────

    test("idempotent: calling twice with same path returns same result", () async {
      plugin.currentProjectResult = PluginProject(
        id: tempDir.path,
        directory: tempDir.path,
        name: "Stable Project",
      );

      final first = await handler.handle(
        makeRequest("POST", "/project/open"),
        body: ProjectPathRequest(path: tempDir.path),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final second = await handler.handle(
        makeRequest("POST", "/project/open"),
        body: ProjectPathRequest(path: tempDir.path),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(first, equals(second));
    });

    test("unhides discovered project id", () async {
      plugin.currentProjectResult = PluginProject(id: tempDir.path, directory: tempDir.path);
      await db.projectsDao.hideProject(projectId: tempDir.path);

      await handler.handle(
        makeRequest("POST", "/project/open"),
        body: ProjectPathRequest(path: tempDir.path),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final hiddenIds = await db.projectsDao.getHiddenProjectIds();
      expect(hiddenIds, isNot(contains(tempDir.path)));
    });
  });
}
