import "dart:io";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/api/filesystem_api.dart";
import "package:sesori_bridge/src/bridge/foundation/filesystem_permission_validator.dart";
import "package:sesori_bridge/src/bridge/repositories/filesystem_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/project_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/repositories/worktree_repository.dart";
import "package:sesori_bridge/src/bridge/routing/open_project_handler.dart";
import "package:sesori_bridge/src/bridge/services/project_activity_service.dart";
import "package:sesori_bridge/src/bridge/services/project_initialization_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fake_filesystem_api.dart";
import "../../helpers/fake_git_cli_api.dart";
import "../../helpers/plugin_runtime_test_support.dart";
import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("OpenProjectHandler", () {
    late FakeBridgePlugin plugin;
    late AppDatabase db;
    late ProjectRepository projectRepository;
    late ProjectActivityService projectActivityService;
    late _ConfigurableGitCliApi gitCliApi;
    late OpenProjectHandler handler;
    late Directory tempDir;
    late File tempFile;

    setUp(() {
      plugin = FakeBridgePlugin();
      db = createTestDatabase();
      tempDir = Directory.systemTemp.createTempSync("sesori_discover_test_");
      tempFile = File("${tempDir.path}/test_file.txt")..createSync();
      gitCliApi = _ConfigurableGitCliApi();
      final filesystemRepository = FilesystemRepository(
        filesystemApi: const FilesystemApi(),
        permissionValidator: const FilesystemPermissionValidator(),
      );
      projectRepository = singlePluginProjectRepository(
        gitCliApi: gitCliApi,
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
        filesystemApi: FakeFilesystemApi(),
      );
      projectActivityService = ProjectActivityService(
        projectRepository: projectRepository,
        projectActivityRepository: singlePluginProjectActivityRepository(
          plugin: plugin,
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
        ),
        now: () => 1234,
      );
      handler = OpenProjectHandler(
        filesystemRepository: filesystemRepository,
        projectInitializationService: ProjectInitializationService(
          worktreeRepository: WorktreeRepository(
            projectsDao: db.projectsDao,
            sessionDao: db.sessionDao,
            gitApi: gitCliApi,
            runtime: createTestPluginRuntime(plugins: [plugin]),
          ),
          filesystemRepository: filesystemRepository,
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
          body: const OpenProjectRequest(path: ""),
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
          body: const OpenProjectRequest(path: "relative/path"),
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
          body: const OpenProjectRequest(path: "/tmp/../etc"),
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
          body: OpenProjectRequest(path: nonExistent),
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
          body: OpenProjectRequest(path: tempFile.path),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    // ── Git setup choice ─────────────────────────────────────────────────────

    test("requires a choice before opening a non-Git folder", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/project/open"),
          body: OpenProjectRequest(
            path: tempDir.path,
            gitAction: OpenProjectGitAction.promptIfNeeded,
          ),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((response) => response.status, "status", 428)),
      );

      expect(plugin.lastGetCurrentProjectProjectId, isNull);
    });

    test("requires a choice when Git is unavailable", () async {
      gitCliApi.insideWorkTreeError = const ProcessException("git", []);

      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/project/open"),
          body: OpenProjectRequest(
            path: tempDir.path,
            gitAction: OpenProjectGitAction.promptIfNeeded,
          ),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((response) => response.status, "status", 428)),
      );
    });

    test("opens a non-Git folder without changing it when requested", () async {
      gitCliApi.insideWorkTreeError = const ProcessException("git", []);
      plugin.currentProjectResult = PluginProject(id: tempDir.path, directory: tempDir.path);

      final result = await handler.handle(
        makeRequest("POST", "/project/open"),
        body: OpenProjectRequest(
          path: tempDir.path,
          gitAction: OpenProjectGitAction.openWithoutGit,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(gitCliApi.initCalls, 0);
      expect(result.supportsDedicatedWorktrees, isFalse);
      expect(plugin.lastGetCurrentProjectProjectId, isNull);
    });

    test("opens an existing Git repository without commits but disables worktrees", () async {
      gitCliApi.initialized = true;
      plugin.currentProjectResult = PluginProject(id: tempDir.path, directory: tempDir.path);

      final result = await handler.handle(
        makeRequest("POST", "/project/open"),
        body: OpenProjectRequest(
          path: tempDir.path,
          gitAction: OpenProjectGitAction.promptIfNeeded,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(gitCliApi.initCalls, 0);
      expect(result.supportsDedicatedWorktrees, isFalse);
      expect(plugin.lastGetCurrentProjectProjectId, isNull);
    });

    test("opens a folder inside an enclosing Git worktree without initializing it", () async {
      gitCliApi.insideWorkTree = true;
      plugin.currentProjectResult = PluginProject(id: tempDir.path, directory: tempDir.path);

      for (final gitAction in [OpenProjectGitAction.promptIfNeeded, OpenProjectGitAction.initializeGit]) {
        final result = await handler.handle(
          makeRequest("POST", "/project/open"),
          body: OpenProjectRequest(
            path: tempDir.path,
            gitAction: gitAction,
          ),
          pathParams: {},
          queryParams: {},
          fragment: null,
        );

        expect(result.supportsDedicatedWorktrees, isFalse);
      }

      expect(gitCliApi.initCalls, 0);
      expect(plugin.lastGetCurrentProjectProjectId, isNull);
    });

    test("an explicit Git action retries setup for a repository without commits", () async {
      gitCliApi.initialized = true;
      plugin.currentProjectResult = PluginProject(id: tempDir.path, directory: tempDir.path);

      final result = await handler.handle(
        makeRequest("POST", "/project/open"),
        body: OpenProjectRequest(
          path: tempDir.path,
          gitAction: OpenProjectGitAction.initializeGit,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(gitCliApi.initCalls, 1);
      expect(gitCliApi.stageCalls, 1);
      expect(gitCliApi.commitCalls, 1);
      expect(result.supportsDedicatedWorktrees, isTrue);
    });

    test("initializes, stages, and commits before opening when Git is enabled", () async {
      plugin.currentProjectResult = PluginProject(id: tempDir.path, directory: tempDir.path);

      final result = await handler.handle(
        makeRequest("POST", "/project/open"),
        body: OpenProjectRequest(
          path: tempDir.path,
          gitAction: OpenProjectGitAction.initializeGit,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(gitCliApi.initCalls, 1);
      expect(gitCliApi.stageCalls, 1);
      expect(gitCliApi.commitCalls, 1);
      expect(result.supportsDedicatedWorktrees, isTrue);
      expect(plugin.lastGetCurrentProjectProjectId, isNull);
    });

    test("still opens the folder when Git setup is incomplete", () async {
      gitCliApi.commitSucceeds = false;
      plugin.currentProjectResult = PluginProject(id: tempDir.path, directory: tempDir.path);

      final result = await handler.handle(
        makeRequest("POST", "/project/open"),
        body: OpenProjectRequest(
          path: tempDir.path,
          gitAction: OpenProjectGitAction.initializeGit,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(gitCliApi.commitCalls, 1);
      expect(result.supportsDedicatedWorktrees, isFalse);
      expect(plugin.lastGetCurrentProjectProjectId, isNull);
    });

    // ── Successful discovery ─────────────────────────────────────────────────

    test("does not call plugin.getProject when opening a project", () async {
      plugin.currentProjectResult = PluginProject(id: tempDir.path, directory: tempDir.path);
      plugin.throwOnGetProjectError = StateError("must not be called");

      await handler.handle(
        makeRequest("POST", "/project/open"),
        body: OpenProjectRequest(path: tempDir.path),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastGetCurrentProjectProjectId, isNull);
    });

    test("returns 200 with application/json content-type", () async {
      plugin.currentProjectResult = PluginProject(id: tempDir.path, directory: tempDir.path);

      final result = await handler.handle(
        makeRequest("POST", "/project/open"),
        body: OpenProjectRequest(path: tempDir.path),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.id, equals(tempDir.path));
    });

    test("maps the bridge-owned project id and local directory name", () async {
      plugin.currentProjectResult = PluginProject(
        id: tempDir.path,
        directory: tempDir.path,
        name: "My Project",
      );

      final result = await handler.handle(
        makeRequest("POST", "/project/open"),
        body: OpenProjectRequest(path: tempDir.path),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.id, equals(tempDir.path));
      expect(result.name, equals(tempDir.path.split(Platform.pathSeparator).last));
    });

    test("maps ProjectTime from the persisted open timestamp", () async {
      plugin.currentProjectResult = PluginProject(
        id: tempDir.path,
        directory: tempDir.path,
        activity: const PluginProjectActivity(createdAt: 1000, updatedAt: 2000),
      );

      final result = await handler.handle(
        makeRequest("POST", "/project/open"),
        body: OpenProjectRequest(path: tempDir.path),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.time, const ProjectTime(created: 1234, updated: 1234));
    });

    test("time is non-null for a newly opened aggregate project", () async {
      plugin.currentProjectResult = PluginProject(id: tempDir.path, directory: tempDir.path);

      final result = await handler.handle(
        makeRequest("POST", "/project/open"),
        body: OpenProjectRequest(path: tempDir.path),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.time, const ProjectTime(created: 1234, updated: 1234));
    });

    // ── Plugin independence ──────────────────────────────────────────────────

    test("opens successfully when plugin.getProject would throw", () async {
      plugin.throwOnGetProjectError = PluginApiException("/project/open", 404);

      final result = await handler.handle(
        makeRequest("POST", "/project/open"),
        body: OpenProjectRequest(path: tempDir.path),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.id, tempDir.path);
      expect(plugin.lastGetCurrentProjectProjectId, isNull);
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
        body: OpenProjectRequest(path: tempDir.path),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final second = await handler.handle(
        makeRequest("POST", "/project/open"),
        body: OpenProjectRequest(path: tempDir.path),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(first, equals(second));
    });

    test("unhides the opened project id", () async {
      plugin.currentProjectResult = PluginProject(id: tempDir.path, directory: tempDir.path);
      await db.projectsDao.hideProject(projectId: tempDir.path);

      await handler.handle(
        makeRequest("POST", "/project/open"),
        body: OpenProjectRequest(path: tempDir.path),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final hiddenIds = await db.projectsDao.getHiddenProjectIds();
      expect(hiddenIds, isNot(contains(tempDir.path)));
    });
  });
}

class _ConfigurableGitCliApi extends FakeGitCliApi {
  bool initialized = false;
  bool insideWorkTree = false;
  Object? insideWorkTreeError;
  bool committed = false;
  bool initSucceeds = true;
  bool stageSucceeds = true;
  bool commitSucceeds = true;
  int initCalls = 0;
  int stageCalls = 0;
  int commitCalls = 0;

  @override
  Future<bool> isGitInitialized({required String projectPath}) async => initialized;

  @override
  Future<bool> isInsideGitWorkTree({required String projectPath}) async {
    if (insideWorkTreeError case final error?) throw error;
    return insideWorkTree;
  }

  @override
  Future<bool> initRepository({required String path}) async {
    initCalls += 1;
    if (initSucceeds) initialized = true;
    return initSucceeds;
  }

  @override
  Future<bool> stageAll({required String projectPath}) async {
    stageCalls += 1;
    return stageSucceeds;
  }

  @override
  Future<bool> commitAll({required String projectPath, required String message}) async {
    commitCalls += 1;
    if (commitSucceeds) committed = true;
    return commitSucceeds;
  }

  @override
  Future<bool> hasAtLeastOneCommit({required String projectPath}) async => committed;
}
