import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/bridge/persistence/hidden_projects_store.dart";
import "package:sesori_bridge/src/bridge/routing/open_project_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("OpenProjectHandler", () {
    late FakeBridgePlugin plugin;
    late HiddenProjectsStore hiddenStore;
    late OpenProjectHandler handler;
    late Directory tempDir;
    late File tempFile;

    setUp(() {
      plugin = FakeBridgePlugin();
      tempDir = Directory.systemTemp.createTempSync("sesori_discover_test_");
      tempFile = File("${tempDir.path}/test_file.txt")..createSync();
      hiddenStore = HiddenProjectsStore.withFile(file: File("${tempDir.path}/hidden_projects.json"));
      handler = OpenProjectHandler(plugin, hiddenStore);
    });

    tearDown(() async {
      await plugin.close();
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
      final response = await handler.handle(
        makeRequest("POST", "/project/open", body: jsonEncode({"path": ""})),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("empty"));
    });

    test("returns 400 when path is relative", () async {
      final response = await handler.handle(
        makeRequest("POST", "/project/open", body: jsonEncode({"path": "relative/path"})),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("absolute"));
    });

    test("returns 400 when path contains path traversal (..) segment", () async {
      final response = await handler.handle(
        makeRequest(
          "POST",
          "/project/open",
          body: jsonEncode({"path": "/tmp/../etc"}),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("traversal"));
    });

    test("returns 400 when body is invalid JSON", () async {
      final response = await handler.handle(
        makeRequest("POST", "/project/open", body: "not-json"),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("invalid JSON body"));
    });

    test("returns 400 when body is missing", () async {
      final response = await handler.handle(
        makeRequest("POST", "/project/open"),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
    });

    // ── Filesystem validation ────────────────────────────────────────────────

    test("returns 404 when path does not exist", () async {
      final nonExistent = "${tempDir.path}/nonexistent-path-xyz";

      final response = await handler.handle(
        makeRequest(
          "POST",
          "/project/open",
          body: jsonEncode({"path": nonExistent}),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(404));
    });

    test("returns 400 when path points to a file not a directory", () async {
      final response = await handler.handle(
        makeRequest(
          "POST",
          "/project/open",
          body: jsonEncode({"path": tempFile.path}),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("directory"));
    });

    // ── Successful discovery ─────────────────────────────────────────────────

    test("calls plugin.getProject with the given path", () async {
      plugin.currentProjectResult = PluginProject(id: tempDir.path);

      await handler.handle(
        makeRequest(
          "POST",
          "/project/open",
          body: jsonEncode({"path": tempDir.path}),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(plugin.lastGetCurrentProjectProjectId, equals(tempDir.path));
    });

    test("returns 200 with application/json content-type", () async {
      plugin.currentProjectResult = PluginProject(id: tempDir.path);

      final response = await handler.handle(
        makeRequest(
          "POST",
          "/project/open",
          body: jsonEncode({"path": tempDir.path}),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(response.headers["content-type"], equals("application/json"));
    });

    test("maps project id and name fields", () async {
      plugin.currentProjectResult = PluginProject(
        id: tempDir.path,
        name: "My Project",
      );

      final response = await handler.handle(
        makeRequest(
          "POST",
          "/project/open",
          body: jsonEncode({"path": tempDir.path}),
        ),
        pathParams: {},
        queryParams: {},
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

      final response = await handler.handle(
        makeRequest(
          "POST",
          "/project/open",
          body: jsonEncode({"path": tempDir.path}),
        ),
        pathParams: {},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as Map<String, dynamic>;
      final time = body["time"] as Map<String, dynamic>;
      expect(time["created"], equals(1000));
      expect(time["updated"], equals(2000));
    });

    test("time is null when plugin returns no time", () async {
      plugin.currentProjectResult = PluginProject(id: tempDir.path);

      final response = await handler.handle(
        makeRequest(
          "POST",
          "/project/open",
          body: jsonEncode({"path": tempDir.path}),
        ),
        pathParams: {},
        queryParams: {},
      );

      final body = jsonDecode(response.body!) as Map<String, dynamic>;
      expect(body["time"], isNull);
    });

    // ── Plugin error propagation ─────────────────────────────────────────────

    test("propagates PluginApiException when plugin.getProject() throws", () async {
      plugin.throwOnGetProjectError = PluginApiException("/project/open", 404);

      await expectLater(
        handler.handle(
          makeRequest(
            "POST",
            "/project/open",
            body: jsonEncode({"path": tempDir.path}),
          ),
          pathParams: {},
          queryParams: {},
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
        makeRequest(
          "POST",
          "/project/open",
          body: jsonEncode({"path": tempDir.path}),
        ),
        pathParams: {},
        queryParams: {},
      );

      final second = await handler.handle(
        makeRequest(
          "POST",
          "/project/open",
          body: jsonEncode({"path": tempDir.path}),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(first.status, equals(200));
      expect(second.status, equals(200));
      expect(first.body, equals(second.body));
    });

    test("unhides discovered project id", () async {
      plugin.currentProjectResult = PluginProject(id: tempDir.path);
      await hiddenStore.hideProject(projectId: tempDir.path);

      await handler.handle(
        makeRequest(
          "POST",
          "/project/open",
          body: jsonEncode({"path": tempDir.path}),
        ),
        pathParams: {},
        queryParams: {},
      );

      final hiddenIds = await hiddenStore.getHiddenProjectIds();
      expect(hiddenIds, isNot(contains(tempDir.path)));
    });
  });
}
