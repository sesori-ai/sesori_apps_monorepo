import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/bridge/routing/create_project_handler.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("CreateProjectHandler", () {
    late _FakeBridgePluginForCreateProject plugin;
    late CreateProjectHandler handler;
    late Directory tempDir;

    setUp(() async {
      plugin = _FakeBridgePluginForCreateProject();
      handler = CreateProjectHandler(plugin);
      tempDir = await Directory.systemTemp.createTemp("create-project-handler-test-");
    });

    tearDown(() async {
      await plugin.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test("canHandle POST /project/create", () {
      expect(handler.canHandle(makeRequest("POST", "/project/create")), isTrue);
    });

    test("valid new path creates directory, runs git init, calls plugin, returns 201", () async {
      final path = "${tempDir.path}/new-project";
      plugin.currentProjectResult = const PluginProject(
        id: "p-1",
        name: "New Project",
        time: PluginProjectTime(created: 10, updated: 20),
      );

      final response = await handler.handle(
        makeRequest(
          "POST",
          "/project",
          body: jsonEncode(CreateProjectRequest(path: path).toJson()),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(Directory(path).existsSync(), isTrue);
      expect(Directory("$path/.git").existsSync(), isTrue);
      expect(plugin.lastGetCurrentProjectProjectId, equals(path));
      expect(response.status, equals(201));
      expect(response.headers["content-type"], equals("application/json"));

      final body = switch (jsonDecode(response.body!)) {
        final Map<String, dynamic> map => map,
        _ => throw StateError("expected JSON object"),
      };
      expect(body["id"], equals("p-1"));
      expect(body["name"], equals("New Project"));
      final time = body["time"] as Map<String, dynamic>;
      expect(time["created"], equals(10));
      expect(time["updated"], equals(20));
    });

    test(".gitignore is created with .worktrees/ entry after git init", () async {
      final path = "${tempDir.path}/new-project-with-gitignore";
      plugin.currentProjectResult = const PluginProject(
        id: "p-2",
        name: "Project With Gitignore",
        time: PluginProjectTime(created: 30, updated: 40),
      );

      final response = await handler.handle(
        makeRequest(
          "POST",
          "/project",
          body: jsonEncode(CreateProjectRequest(path: path).toJson()),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(201));

      final gitignoreFile = File("$path/.gitignore");
      expect(gitignoreFile.existsSync(), isTrue);

      final gitignoreContent = await gitignoreFile.readAsString();
      expect(gitignoreContent, contains(".worktrees/"));
    });

    test("path that already exists as directory returns 409", () async {
      final existing = Directory("${tempDir.path}/existing")..createSync();

      final response = await handler.handle(
        makeRequest(
          "POST",
          "/project",
          body: jsonEncode(CreateProjectRequest(path: existing.path).toJson()),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(409));
      expect(response.body, contains("directory already exists"));
    });

    test("empty path returns 400", () async {
      final response = await handler.handle(
        makeRequest(
          "POST",
          "/project",
          body: jsonEncode(const CreateProjectRequest(path: "").toJson()),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("path must not be empty"));
    });

    test("relative path returns 400", () async {
      final response = await handler.handle(
        makeRequest(
          "POST",
          "/project",
          body: jsonEncode(const CreateProjectRequest(path: "relative/project").toJson()),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("path must be absolute"));
    });

    test("path traversal returns 400", () async {
      final response = await handler.handle(
        makeRequest(
          "POST",
          "/project",
          body: jsonEncode(CreateProjectRequest(path: "${tempDir.path}/../escape").toJson()),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("path traversal not allowed"));
    });

    test("parent directory does not exist returns 400", () async {
      final path = "${tempDir.path}/missing-parent/project";

      final response = await handler.handle(
        makeRequest(
          "POST",
          "/project",
          body: jsonEncode(CreateProjectRequest(path: path).toJson()),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("parent directory does not exist"));
    });

    test("plugin getProject PluginApiException is forwarded", () async {
      final path = "${tempDir.path}/plugin-error";
      plugin.injectGetProjectError = PluginApiException("/project", 503);

      await expectLater(
        () => handler.handle(
          makeRequest(
            "POST",
            "/project",
            body: jsonEncode(CreateProjectRequest(path: path).toJson()),
          ),
          pathParams: {},
          queryParams: {},
        ),
        throwsA(isA<PluginApiException>()),
      );
    });
  });
}

class _FakeBridgePluginForCreateProject extends FakeBridgePlugin {
  Object? injectGetProjectError;

  @override
  Future<PluginProject> getProject(String projectId) async {
    if (injectGetProjectError case final error?) {
      throw error;
    }
    return super.getProject(projectId);
  }
}
