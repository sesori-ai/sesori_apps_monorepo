import "dart:io";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/api/filesystem_api.dart";
import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/filesystem_permission_validator.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/repositories/filesystem_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/project_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/repositories/worktree_repository.dart";
import "package:sesori_bridge/src/bridge/routing/create_project_handler.dart";
import "package:sesori_bridge/src/bridge/services/project_activity_service.dart";
import "package:sesori_bridge/src/bridge/services/project_initialization_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fake_filesystem_api.dart";
import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("CreateProjectHandler", () {
    late _FakeBridgePluginForCreateProject plugin;
    late AppDatabase db;
    late CreateProjectHandler handler;
    late ProjectActivityService projectActivityService;
    late Directory tempDir;

    setUp(() async {
      plugin = _FakeBridgePluginForCreateProject();
      db = createTestDatabase();
      final filesystemRepository = FilesystemRepository(
        filesystemApi: const FilesystemApi(),
        permissionValidator: const FilesystemPermissionValidator(),
      );
      projectActivityService = ProjectActivityService(
        projectRepository: ProjectRepository(
          plugin: plugin,
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
          unseenCalculator: const SessionUnseenCalculator(),
          filesystemApi: FakeFilesystemApi(),
        ),
        now: () => 1234,
      );
      handler = CreateProjectHandler(
        projectInitializationService: ProjectInitializationService(
          worktreeRepository: WorktreeRepository(
            projectsDao: db.projectsDao,
            sessionDao: db.sessionDao,
            plugin: plugin,
            gitApi: GitCliApi(
              processRunner: ProcessRunner(),
              gitPathExists: ({required String gitPath}) =>
                  FileSystemEntity.typeSync(gitPath) != FileSystemEntityType.notFound,
            ),
          ),
          filesystemRepository: filesystemRepository,
        ),
        projectActivityService: projectActivityService,
      );
      tempDir = await Directory.systemTemp.createTemp("create-project-handler-test-");
    });

    tearDown(() async {
      await projectActivityService.dispose();
      await plugin.close();
      await db.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test("canHandle POST /project/create", () {
      expect(handler.canHandle(makeRequest("POST", "/project/create")), isTrue);
    });

    test("valid new path creates directory, runs git init, calls plugin, returns 200", () async {
      final path = "${tempDir.path}/new-project";
      plugin.currentProjectResult = PluginProject(
        id: "p-1",
        directory: path,
        name: "New Project",
        activity: const PluginProjectActivity(createdAt: 10, updatedAt: 20),
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
      expect(result.time, const ProjectTime(created: 1234, updated: 1234));
    });

    test(".gitignore is created with .worktrees/ entry after git init", () async {
      final path = "${tempDir.path}/new-project-with-gitignore";
      plugin.currentProjectResult = PluginProject(
        id: "p-2",
        directory: path,
        name: "Project With Gitignore",
        activity: const PluginProjectActivity(createdAt: 30, updatedAt: 40),
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
