import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/bridge/persistence/daos/projects_dao.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/routing/open_project_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("OpenProjectHandler", () {
    late FakeBridgePlugin plugin;
    late AppDatabase db;
    late ProjectsDao hiddenStore;
    late OpenProjectHandler handler;
    late Directory tempDir;
    late File tempFile;

    setUp(() {
      plugin = FakeBridgePlugin();
      db = createTestDatabase();
      tempDir = Directory.systemTemp.createTempSync("sesori_discover_test_");
      tempFile = File("${tempDir.path}/test_file.txt")..createSync();
      hiddenStore = db.projectsDao;
      handler = OpenProjectHandler(plugin, hiddenStore);
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
      final response = await handler.handleInternal(
        makeRequest("POST", "/project/open", body: jsonEncode({"path": ""})),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(400));
      expect(response.body, contains("empty"));
    });

    test("returns 400 when path is relative", () async {
      final response = await handler.handleInternal(
        makeRequest("POST", "/project/open", body: jsonEncode({"path": "relative/path"})),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(400));
      expect(response.body, contains("absolute"));
    });

    test("returns 400 when path contains path traversal (..) segment", () async {
      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/project/open",
          body: jsonEncode({"path": "/tmp/../etc"}),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(400));
      expect(response.body, contains("traversal"));
    });

    // ── Filesystem validation ────────────────────────────────────────────────

    test("returns 404 when path does not exist", () async {
      final nonExistent = "${tempDir.path}/nonexistent-path-xyz";

      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/project/open",
          body: jsonEncode({"path": nonExistent}),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(404));
    });

    test("returns 400 when path points to a file not a directory", () async {
      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/project/open",
          body: jsonEncode({"path": tempFile.path}),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(400));
      expect(response.body, contains("directory"));
    });

    // ── Successful discovery ─────────────────────────────────────────────────

    test("calls plugin.getProject with the given path", () async {
      plugin.currentProjectResult = PluginProject(id: tempDir.path);

      await handler.handleInternal(
        makeRequest(
          "POST",
          "/project/open",
          body: jsonEncode({"path": tempDir.path}),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastGetCurrentProjectProjectId, equals(tempDir.path));
    });

    test("returns 200 with application/json content-type", () async {
      plugin.currentProjectResult = PluginProject(id: tempDir.path);

      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/project/open",
          body: jsonEncode({"path": tempDir.path}),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(200));
      expect(response.headers["content-type"], equals("application/json"));
    });

    test("maps project id and name fields", () async {
      plugin.currentProjectResult = PluginProject(
        id: tempDir.path,
        name: "My Project",
      );

      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/project/open",
          body: jsonEncode({"path": tempDir.path}),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final body = switch (jsonDecode(response.body!)) {
        final Map<String, dynamic> map => map,
        _ => throw StateError("expected JSON object"),
      };
      expect(body["id"], equals(tempDir.path));
      expect(body["name"], equals("My Project"));
    });

    test("maps ProjectTime when plugin returns time", () async {
      plugin.currentProjectResult = PluginProject(
        id: tempDir.path,
        time: const PluginProjectTime(created: 1000, updated: 2000),
      );

      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/project/open",
          body: jsonEncode({"path": tempDir.path}),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final body = jsonDecode(response.body!) as Map<String, dynamic>;
      final time = body["time"] as Map<String, dynamic>;
      expect(time["created"], equals(1000));
      expect(time["updated"], equals(2000));
    });

    test("time is null when plugin returns no time", () async {
      plugin.currentProjectResult = PluginProject(id: tempDir.path);

      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/project/open",
          body: jsonEncode({"path": tempDir.path}),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final body = jsonDecode(response.body!) as Map<String, dynamic>;
      expect(body["time"], isNull);
    });

    // ── Plugin error propagation ─────────────────────────────────────────────

    test("returns 500 when plugin.getProject() throws", () async {
      plugin.throwOnGetProjectError = PluginApiException("/project/open", 404);

      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/project/open",
          body: jsonEncode({"path": tempDir.path}),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(500));
      expect(response.body, contains("Internal Server Error"));
    });

    // ── Idempotency ──────────────────────────────────────────────────────────

    test("idempotent: calling twice with same path returns same result", () async {
      plugin.currentProjectResult = PluginProject(
        id: tempDir.path,
        name: "Stable Project",
      );

      final first = await handler.handleInternal(
        makeRequest(
          "POST",
          "/project/open",
          body: jsonEncode({"path": tempDir.path}),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final second = await handler.handleInternal(
        makeRequest(
          "POST",
          "/project/open",
          body: jsonEncode({"path": tempDir.path}),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(first.status, equals(200));
      expect(second.status, equals(200));
      expect(first.body, equals(second.body));
    });

    test("unhides discovered project id", () async {
      plugin.currentProjectResult = PluginProject(id: tempDir.path);
      await hiddenStore.hideProject(projectId: tempDir.path);

      await handler.handleInternal(
        makeRequest(
          "POST",
          "/project/open",
          body: jsonEncode({"path": tempDir.path}),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final hiddenIds = await hiddenStore.getHiddenProjectIds();
      expect(hiddenIds, isNot(contains(tempDir.path)));
    });
  });
}
