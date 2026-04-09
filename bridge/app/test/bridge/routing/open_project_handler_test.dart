import "dart:io";

import "package:sesori_bridge/src/bridge/persistence/daos/projects_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/routing/open_project_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("OpenProjectHandler", () {
    late FakeBridgePlugin plugin;
    late AppDatabase db;
    late ProjectsDao projectsDao;
    late OpenProjectHandler handler;
    late Directory tempDir;
    late File tempFile;

    setUp(() {
      plugin = FakeBridgePlugin();
      db = createTestDatabase();
      tempDir = Directory.systemTemp.createTempSync("sesori_discover_test_");
      tempFile = File("${tempDir.path}/test_file.txt")..createSync();
      projectsDao = db.projectsDao;
      handler = OpenProjectHandler(plugin, projectsDao);
    });

    tearDown(() async {
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
      plugin.currentProjectResult = PluginProject(id: tempDir.path);

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
      plugin.currentProjectResult = PluginProject(id: tempDir.path);

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

    test("maps ProjectTime when plugin returns time", () async {
      plugin.currentProjectResult = PluginProject(
        id: tempDir.path,
        time: const PluginProjectTime(created: 1000, updated: 2000),
      );

      final result = await handler.handle(
        makeRequest("POST", "/project/open"),
        body: ProjectPathRequest(path: tempDir.path),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.time?.created, equals(1000));
      expect(result.time?.updated, equals(2000));
    });

    test("time is null when plugin returns no time", () async {
      plugin.currentProjectResult = PluginProject(id: tempDir.path);

      final result = await handler.handle(
        makeRequest("POST", "/project/open"),
        body: ProjectPathRequest(path: tempDir.path),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.time, isNull);
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
      plugin.currentProjectResult = PluginProject(id: tempDir.path);
      await projectsDao.hideProject(projectId: tempDir.path);

      await handler.handle(
        makeRequest("POST", "/project/open"),
        body: ProjectPathRequest(path: tempDir.path),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final hiddenIds = await projectsDao.getHiddenProjectIds();
      expect(hiddenIds, isNot(contains(tempDir.path)));
    });
  });
}
