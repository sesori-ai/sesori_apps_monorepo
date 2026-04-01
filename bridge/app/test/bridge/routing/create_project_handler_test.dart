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

    test("valid new path creates directory, runs git init, calls plugin, returns 200", () async {
      final path = "${tempDir.path}/new-project";
      plugin.currentProjectResult = const PluginProject(
        id: "p-1",
        name: "New Project",
        time: PluginProjectTime(created: 10, updated: 20),
      );

      final result = await handler.handle(
        makeRequest("POST", "/project/create"),
        body: ProjectPathRequest(path: path),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(Directory(path).existsSync(), isTrue);
      expect(Directory("$path/.git").existsSync(), isTrue);
      expect(plugin.lastGetCurrentProjectProjectId, equals(path));
      expect(result.id, equals("p-1"));
      expect(result.name, equals("New Project"));
      expect(result.time?.created, equals(10));
      expect(result.time?.updated, equals(20));
    });

    test(".gitignore is created with .worktrees/ entry after git init", () async {
      final path = "${tempDir.path}/new-project-with-gitignore";
      plugin.currentProjectResult = const PluginProject(
        id: "p-2",
        name: "Project With Gitignore",
        time: PluginProjectTime(created: 30, updated: 40),
      );

      final result = await handler.handle(
        makeRequest("POST", "/project/create"),
        body: ProjectPathRequest(path: path),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.id, equals("p-2"));

      final gitignoreFile = File("$path/.gitignore");
      expect(gitignoreFile.existsSync(), isTrue);

      final gitignoreContent = await gitignoreFile.readAsString();
      expect(gitignoreContent, contains(".worktrees/"));
    });

    test("path that already exists as directory returns 409", () async {
      final existing = Directory("${tempDir.path}/existing")..createSync();

      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/project/create"),
          body: ProjectPathRequest(path: existing.path),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(409))),
      );
    });

    test("empty path returns 400", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/project/create"),
          body: const ProjectPathRequest(path: ""),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    test("relative path returns 400", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/project/create"),
          body: const ProjectPathRequest(path: "relative/project"),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    test("path traversal returns 400", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/project/create"),
          body: ProjectPathRequest(path: "${tempDir.path}/../escape"),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    test("parent directory does not exist returns 400", () async {
      final path = "${tempDir.path}/missing-parent/project";

      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/project/create"),
          body: ProjectPathRequest(path: path),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    test("plugin getProject PluginApiException returns 500", () async {
      final path = "${tempDir.path}/plugin-error";
      plugin.injectGetProjectError = PluginApiException("/project", 503);

      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/project/create"),
          body: ProjectPathRequest(path: path),
          pathParams: {},
          queryParams: {},
          fragment: null,
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
