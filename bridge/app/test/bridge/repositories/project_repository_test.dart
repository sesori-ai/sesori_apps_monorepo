import "dart:async";

import "package:sesori_bridge/src/api/database/daos/projects_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/database/tables/projects_table.dart";
import "package:sesori_bridge/src/bridge/repositories/models/project_activity.dart";
import "package:sesori_bridge/src/bridge/repositories/models/project_not_found_exception.dart";
import "package:sesori_bridge/src/bridge/repositories/project_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/services/project_activity_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fake_filesystem_api.dart";
import "../../helpers/fake_git_cli_api.dart";
import "../../helpers/test_database.dart";

void main() {
  group("ProjectRepository", () {
    late AppDatabase db;
    late _FakeBridgePlugin plugin;
    late ProjectRepository repo;

    setUp(() {
      db = createTestDatabase();
      plugin = _FakeBridgePlugin();
      repo = singlePluginProjectRepository(
        gitCliApi: FakeGitCliApi(),
        plugin: plugin,
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
        filesystemApi: FakeFilesystemApi(),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test("getProjects reads stored projects, filters hidden, and keeps SQL order", () async {
      plugin.projectsResult = const [
        PluginProject(id: "p1", directory: "p1", name: "P1"),
        PluginProject(id: "p2", directory: "p2", name: "P2"),
        PluginProject(id: "p3", directory: "p3", name: "P3"),
      ];

      // Pre-hide p2 and stamp each visible project's persisted updatedAt so
      // the sort order is deterministic and comes from the DTO, not the plugin.
      await db.projectsDao.hideProject(projectId: "p2");
      await db.projectsDao.setActivity(
        projectId: "p1",
        createdAt: 0,
        updatedAt: 100,
      );
      await db.projectsDao.setActivity(
        projectId: "p3",
        createdAt: 0,
        updatedAt: 300,
      );

      final result = await repo.getProjects();

      expect(plugin.getProjectsCallCount, 0);
      final rows = await db.select(db.projectsTable).get();
      expect(
        rows.map((r) => r.projectId).toSet(),
        equals({"p1", "p2", "p3"}),
        reason: "catalog reads must not alter stored projects",
      );

      // (b) Returned list filters p2 out.
      expect(result, hasLength(2));

      // (c) Order is [p3, p1] — sorted by persisted updatedAt descending.
      expect(result.map((p) => p.id).toList(), equals(["p3", "p1"]));
    });

    test("getProjects maps the stored path independently from the project id", () async {
      plugin.projectsResult = const [
        PluginProject(id: "backend-project-1", directory: "/projects/one", name: "One"),
      ];

      await db.projectsDao.recordOpenedProject(
        projectId: "backend-project-1",
        path: "/projects/one",
        displayName: null,
        createdAt: 1,
        updatedAt: 2,
      );

      final result = await repo.getProjects();

      expect(result.single.id, "backend-project-1");
      expect(result.single.path, "/projects/one");
      expect(
        (await db.projectsDao.getProject(projectId: "backend-project-1"))!.path,
        "/projects/one",
      );
      expect(plugin.getProjectsCallCount, 0);
    });

    test("activity reconciliation seeds native directories and preserves existing paths", () async {
      plugin.projectsResult = const [
        PluginProject(
          id: "new-project",
          directory: "/projects/new",
          activity: PluginProjectActivity(createdAt: 10, updatedAt: 20),
        ),
        PluginProject(
          id: "moved-project",
          directory: "/projects/backend-path",
          activity: PluginProjectActivity(createdAt: 50, updatedAt: 60),
        ),
      ];
      await db.projectsDao.recordOpenedProject(
        projectId: "moved-project",
        path: "/projects/moved",
        displayName: null,
        createdAt: 1,
        updatedAt: 1,
      );
      final service = ProjectActivityService(projectRepository: repo, now: () => 9999);
      addTearDown(service.dispose);

      await service.reconcile(pluginId: null);

      final newProject = await db.projectsDao.getProject(projectId: "new-project");
      expect(newProject?.path, "/projects/new");
      expect(newProject?.createdAt, 10);
      expect(newProject?.updatedAt, 20);
      final movedProject = await db.projectsDao.getProject(projectId: "moved-project");
      expect(movedProject?.path, "/projects/moved");
      expect(movedProject?.updatedAt, 60, reason: "stable native identity must retain activity after a move");
    });

    test("native activity reuses an existing path-canonical project row", () async {
      const directory = "/projects/shared";
      plugin.projectsResult = const [
        PluginProject(
          id: "native-project-id",
          directory: directory,
          activity: PluginProjectActivity(createdAt: 10, updatedAt: 20),
        ),
      ];
      await db.projectsDao.recordOpenedProject(
        projectId: directory,
        path: directory,
        displayName: null,
        createdAt: 1,
        updatedAt: 2,
      );

      final evidence = await repo.listProjectActivityEvidence(pluginId: plugin.id);

      expect(evidence.single.projectId, directory);
      expect((await db.projectsDao.getAllProjects()).map((project) => project.projectId), [directory]);
    });

    test("getProjects completes from the catalog when plugin enumeration throws", () async {
      plugin.getProjectsError = PluginApiException("/project", 500);
      await db.projectsDao.setActivity(projectId: "stored", createdAt: 1, updatedAt: 2);

      final projects = await repo.getProjects().timeout(const Duration(seconds: 1));

      expect(projects.single.id, "stored");
      expect(plugin.getProjectsCallCount, 0);
    });

    test("project list and detail complete while plugin reads never complete", () async {
      plugin.getProjectsFuture = Completer<List<PluginProject>>().future;
      await db.projectsDao.setActivity(projectId: "stored", createdAt: 1, updatedAt: 2);

      final projects = await repo.getProjects().timeout(const Duration(seconds: 1));
      final project = await repo.getProject(projectId: "stored").timeout(const Duration(seconds: 1));

      expect(projects.single, project);
      expect(plugin.getProjectsCallCount, 0);
      expect(plugin.lastGetProjectId, isNull);
    });

    test("getProjects does not seed projects that only exist in the plugin", () async {
      plugin.projectsResult = const [
        PluginProject(id: "p1", directory: "p1"),
        PluginProject(id: "p2", directory: "p2"),
        PluginProject(id: "p3", directory: "p3"),
        PluginProject(id: "p4", directory: "p4"),
      ];

      await repo.getProjects();

      final rows = await db.select(db.projectsTable).get();
      expect(rows, isEmpty);
      expect(plugin.getProjectsCallCount, 0);
    });

    test("getProjects maps stored activity without plugin evidence", () async {
      plugin.projectsResult = const [
        PluginProject(
          id: "direct",
          directory: "direct",
          activity: PluginProjectActivity(createdAt: 10, updatedAt: 20),
        ),
        PluginProject(id: "default", directory: "default"),
      ];

      await db.projectsDao.setActivity(projectId: "direct", createdAt: 10, updatedAt: 20);
      await db.projectsDao.setActivity(projectId: "default", createdAt: 1234, updatedAt: 1234);
      final result = await repo.getProjects();
      final rows = {for (final row in await db.projectsDao.getAllProjects()) row.projectId: row};

      expect(rows["direct"]!.createdAt, 10);
      expect(rows["direct"]!.updatedAt, 20);
      expect(rows["default"]!.createdAt, 1234);
      expect(rows["default"]!.updatedAt, 1234);
      expect(result.every((project) => project.time != null), isTrue);
    });

    test("getProjects uses one catalog project query", () async {
      plugin.projectsResult = const [
        PluginProject(
          id: "new",
          directory: "new",
          activity: PluginProjectActivity(createdAt: 10, updatedAt: 20),
        ),
      ];
      final projectsDao = _CountingProjectsDao(database: db);
      final countingRepo = singlePluginProjectRepository(
        gitCliApi: FakeGitCliApi(),
        plugin: plugin,
        projectsDao: projectsDao,
        sessionDao: db.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
        filesystemApi: FakeFilesystemApi(),
      );
      await db.projectsDao.setActivity(projectId: "new", createdAt: 10, updatedAt: 20);

      final result = await countingRepo.getProjects();

      expect(projectsDao.getCatalogProjectsCallCount, 1);
      expect(result.single.time, const ProjectTime(created: 10, updated: 20));
    });

    test("getProjects breaks equal timestamps by project id descending", () async {
      plugin.projectsResult = const [
        PluginProject(id: "z", directory: "z", name: "Beta"),
        PluginProject(id: "b", directory: "b", name: "Alpha"),
        PluginProject(id: "a", directory: "a", name: "Alpha"),
      ];
      for (final id in ["z", "b", "a"]) {
        await db.projectsDao.setActivity(projectId: id, createdAt: 1, updatedAt: 10);
      }

      final result = await repo.getProjects();

      expect(result.map((project) => project.id), ["z", "b", "a"]);
    });

    test("openProject discovers via plugin, unhides stored row, and maps result", () async {
      plugin.projectResult = const PluginProject(
        id: "p-open",
        directory: "/tmp/p-open",
        name: "Opened",
      );
      await db.projectsDao.hideProject(projectId: "p-open");

      final target = await repo.resolveProjectOpenTarget(path: "/tmp/p-open");
      await repo.persistOpenedProject(
        target: target,
        activity: const ProjectActivity(createdAt: 1, updatedAt: 2),
      );
      final result = await repo.mapOpenedProject(target: target);

      expect(plugin.lastGetProjectId, equals("/tmp/p-open"));
      expect(result.id, equals("p-open"));
      expect(result.name, equals("Opened"));
      final hiddenIds = await db.projectsDao.getHiddenProjectIds();
      expect(hiddenIds, isNot(contains("p-open")));
    });

    test("opening a new native project persists its backend display name", () async {
      plugin.projectResult = const PluginProject(
        id: "p-new",
        directory: "/tmp/p-new",
        name: "Backend project name",
      );

      final target = await repo.resolveProjectOpenTarget(path: "/tmp/p-new");
      await repo.persistOpenedProject(
        target: target,
        activity: const ProjectActivity(createdAt: 1, updatedAt: 2),
      );

      expect((await repo.getProjects()).single.name, "Backend project name");
    });

    test("opening a native project reuses the normalized-path catalog row", () async {
      const directory = "/tmp/projects/shared";
      plugin.projectResult = const PluginProject(
        id: "native-project-id",
        directory: directory,
        name: "Native project",
      );
      await db.projectsDao.recordOpenedProject(
        projectId: directory,
        path: "$directory/.",
        displayName: null,
        createdAt: 1,
        updatedAt: 1,
      );

      final target = await repo.resolveProjectOpenTarget(path: directory);
      await repo.persistOpenedProject(
        target: target,
        activity: const ProjectActivity(createdAt: 1, updatedAt: 2),
      );
      final opened = await repo.mapOpenedProject(target: target);

      expect(opened.id, directory);
      expect((await db.projectsDao.getAllProjects()).map((project) => project.projectId), [directory]);
    });

    test("reopening a native project preserves its user display name", () async {
      plugin.projectResult = const PluginProject(
        id: "p-renamed",
        directory: "/tmp/p-renamed",
        name: "Backend project name",
      );
      await db.projectsDao.recordOpenedProject(
        projectId: "p-renamed",
        path: "/tmp/p-renamed",
        displayName: null,
        createdAt: 1,
        updatedAt: 1,
      );
      await db.projectsDao.setDisplayName(
        projectId: "p-renamed",
        displayName: "User project name",
        updatedAt: 1,
      );

      final target = await repo.resolveProjectOpenTarget(path: "/tmp/p-renamed");
      await repo.persistOpenedProject(
        target: target,
        activity: const ProjectActivity(createdAt: 1, updatedAt: 2),
      );

      expect((await repo.getProjects()).single.name, "User project name");
    });

    group("moved project (stable id, new live path)", () {
      test("openProject keys the row on the canonical id and stores the opened path", () async {
        // OpenCode-style backend: the folder moved from /projects/a to
        // /moved/a, and the backend keeps reporting the pinned original
        // worktree as the project id.
        plugin.projectResult = const PluginProject(id: "/projects/a", directory: "/moved/a", name: "A");
        await db.projectsDao.hideProject(projectId: "/projects/a");
        await db.projectsDao.setBaseBranch(projectId: "/projects/a", baseBranch: "develop");

        final target = await repo.resolveProjectOpenTarget(path: "/moved/a");
        await repo.persistOpenedProject(
          target: target,
          activity: const ProjectActivity(createdAt: 1, updatedAt: 2),
        );
        final result = await repo.mapOpenedProject(target: target);

        expect(result.id, equals("/projects/a"));
        expect(result.path, equals("/moved/a"));
        final row = await db.projectsDao.getProject(projectId: "/projects/a");
        expect(row!.path, equals("/moved/a"), reason: "the live path is recorded on the canonical row");
        expect(row.hidden, isFalse, reason: "re-opening unhides the canonical row");
        expect(
          row.baseBranch,
          equals("develop"),
          reason: "durable state survives the move — the row key never changed",
        );
      });

      test("getProjects surfaces a re-opened moved project at its new path", () async {
        // Regression: remapping the id to the opened directory (instead of
        // storing a path) made the next list refresh drop the project — the
        // plugin list still reported the old id, which stayed hidden.
        plugin.projectResult = const PluginProject(id: "/projects/a", directory: "/moved/a", name: "A");
        plugin.projectsResult = const [
          PluginProject(id: "/projects/a", directory: "/projects/a", name: "A"),
        ];
        await db.projectsDao.hideProject(projectId: "/projects/a");
        await db.projectsDao.setActivity(
          projectId: "/projects/a",
          createdAt: 0,
          updatedAt: 1,
        );
        final target = await repo.resolveProjectOpenTarget(path: "/moved/a");
        await repo.persistOpenedProject(
          target: target,
          activity: const ProjectActivity(createdAt: 0, updatedAt: 1),
        );

        final result = await repo.getProjects();

        expect(result, hasLength(1));
        expect(result.single.id, equals("/projects/a"));
        expect(result.single.path, equals("/moved/a"));
      });

      test("getProjects computes directoryMissing against the live path, not the id", () async {
        plugin.projectResult = const PluginProject(id: "/projects/a", directory: "/moved/a", name: "A");
        plugin.projectsResult = const [
          PluginProject(id: "/projects/a", directory: "/projects/a", name: "A"),
        ];
        final repoWithMissing = singlePluginProjectRepository(
          gitCliApi: FakeGitCliApi(),
          plugin: plugin,
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
          unseenCalculator: const SessionUnseenCalculator(),
          // The original location is gone; the folder lives at /moved/a now.
          filesystemApi: FakeFilesystemApi(missingPaths: {"/projects/a"}),
        );
        final target = await repoWithMissing.resolveProjectOpenTarget(path: "/moved/a");
        await repoWithMissing.persistOpenedProject(
          target: target,
          activity: const ProjectActivity(createdAt: 0, updatedAt: 1),
        );

        final result = await repoWithMissing.getProjects();

        expect(result.firstWhere((p) => p.id == "/projects/a").directoryMissing, isFalse);
      });

      test("getProject is catalog-only while renameProject hands the plugin the live path", () async {
        plugin.projectResult = const PluginProject(id: "/projects/a", directory: "/moved/a", name: "A");
        await db.projectsDao.recordOpenedProject(
          projectId: "/projects/a",
          path: "/moved/a",
          displayName: null,
          createdAt: 0,
          updatedAt: 1,
        );

        final fetched = await repo.getProject(projectId: "/projects/a");
        expect(plugin.lastGetProjectId, isNull);
        expect(fetched.path, equals("/moved/a"));

        final renamed = await repo.renameProject(projectId: "/projects/a", name: "Renamed");
        expect(plugin.lastRenameProjectId, equals("/moved/a"));
        expect(renamed.path, equals("/moved/a"));
      });
    });

    test("hideProject persists hidden project id", () async {
      await repo.hideProject(projectId: "p-hidden");

      final hiddenIds = await db.projectsDao.getHiddenProjectIds();
      expect(hiddenIds, contains("p-hidden"));
    });

    test("getBaseBranch returns stored branch", () async {
      await db.projectsDao.setBaseBranch(projectId: "p-base", baseBranch: "develop");

      final result = await repo.getBaseBranch(projectId: "p-base");

      expect(result, equals("develop"));
    });

    test("setBaseBranch stores branch", () async {
      await repo.setBaseBranch(projectId: "p-set", baseBranch: "main");

      final stored = await db.projectsDao.getBaseBranch(projectId: "p-set");
      expect(stored, equals("main"));
    });

    test("getProjects leaves directoryMissing false without filesystem probes", () async {
      plugin.projectsResult = const [
        PluginProject(id: "/present", directory: "/present", name: "Present"),
        PluginProject(id: "/moved", directory: "/moved", name: "Moved"),
      ];
      final repoWithMissing = singlePluginProjectRepository(
        gitCliApi: FakeGitCliApi(),
        plugin: plugin,
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
        filesystemApi: FakeFilesystemApi(missingPaths: {"/moved"}),
      );
      await db.projectsDao.setActivity(
        projectId: "/present",
        createdAt: 0,
        updatedAt: 2,
      );
      await db.projectsDao.setActivity(
        projectId: "/moved",
        createdAt: 0,
        updatedAt: 1,
      );

      final result = await repoWithMissing.getProjects();

      expect(result.firstWhere((p) => p.id == "/present").directoryMissing, isFalse);
      expect(result.firstWhere((p) => p.id == "/moved").directoryMissing, isFalse);
    });

    test("getProject leaves directoryMissing false without a filesystem probe", () async {
      plugin.projectResult = const PluginProject(id: "/gone", directory: "/gone", name: "Gone");
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/gone"]);
      final repoWithMissing = singlePluginProjectRepository(
        gitCliApi: FakeGitCliApi(),
        plugin: plugin,
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
        filesystemApi: FakeFilesystemApi(missingPaths: {"/gone"}),
      );

      final result = await repoWithMissing.getProject(projectId: "/gone");

      expect(result.directoryMissing, isFalse);
      expect(plugin.lastGetProjectId, isNull);
    });

    test("a directory whose existence probe throws is treated as present, not missing", () async {
      await db.projectsDao.setActivity(projectId: "/denied", createdAt: 1, updatedAt: 2);
      final repoWithThrow = singlePluginProjectRepository(
        gitCliApi: FakeGitCliApi(),
        plugin: plugin,
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
        filesystemApi: FakeFilesystemApi(throwingPaths: {"/denied"}),
      );

      final result = await repoWithThrow.getProjects();

      expect(result.single.directoryMissing, isFalse);
    });
  });

  group("ProjectRepository (bridge-derived)", () {
    late AppDatabase db;
    late _FakeDerivedPlugin plugin;
    late ProjectRepository repo;

    setUp(() {
      db = createTestDatabase();
      plugin = _FakeDerivedPlugin([]);
      repo = singlePluginProjectRepository(
        gitCliApi: FakeGitCliApi(),
        plugin: plugin,
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
        filesystemApi: FakeFilesystemApi(),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test("getProjects reads imported derived projects without enumerating sessions", () async {
      plugin.sessions = [
        _session("/tmp/proj/alpha", id: "a1", created: 10, updated: 20),
        _session("/tmp/proj/alpha", id: "a2", created: 5, updated: 50),
        _session("/tmp/proj/beta", id: "b1", created: 1, updated: 1),
      ];
      // The derived project time comes from the persisted DTO, so seed the
      // updated timestamps to make the sort order deterministic.
      await db.projectsDao.setActivity(
        projectId: "/tmp/proj/alpha",
        createdAt: 5,
        updatedAt: 50,
      );
      await db.projectsDao.setActivity(
        projectId: "/tmp/proj/beta",
        createdAt: 1,
        updatedAt: 1,
      );

      final result = await repo.getProjects();

      expect(result.map((p) => p.id).toSet(), {"/tmp/proj/alpha", "/tmp/proj/beta"});
      final rows = await db.select(db.projectsTable).get();
      expect(rows.map((r) => r.projectId).toSet(), containsAll({"/tmp/proj/alpha", "/tmp/proj/beta"}));
      // Sorted by persisted updatedAt descending: alpha (50) before beta (1).
      expect(result.first.id, "/tmp/proj/alpha");
      expect(plugin.listAllSessionsCallCount, 0);
    });

    test("normal listing does not seed derived plugin sessions", () async {
      plugin.sessions = [
        _session("/tmp/proj/alpha", id: "a1", created: 20, updated: 30),
        _session("/tmp/proj/alpha", id: "a2", created: 10, updated: 40),
      ];
      final service = ProjectActivityService(projectRepository: repo, now: () => 9999);
      addTearDown(service.dispose);

      final result = await service.getProjects();

      expect(result, isEmpty);
      final row = await db.projectsDao.getProject(projectId: "/tmp/proj/alpha");
      expect(row, isNull);
      expect(plugin.listAllSessionsCallCount, 0);
    });

    test("getProjects omits a project flagged hidden", () async {
      plugin.sessions = [_session("/tmp/proj/alpha", created: 1, updated: 1)];
      await db.projectsDao.hideProject(projectId: "/tmp/proj/alpha");

      expect(await repo.getProjects(), isEmpty);
    });

    test("getProjects retains durable projects regardless of plugin tombstones", () async {
      // The backend has no session deletion, so it keeps enumerating the
      // deleted session — its project must not resurrect from it.
      plugin.sessions = [
        _session("/tmp/proj/alpha", id: "kept", created: 1, updated: 1),
        _session("/tmp/proj/deleted-only", id: "gone", created: 1, updated: 1),
      ];
      await db.sessionDao.insertSessionTombstone(backendSessionId: "gone", pluginId: "codex", deletedAt: 1);
      await db.projectsDao.setActivity(projectId: "/tmp/proj/alpha", createdAt: 1, updatedAt: 2);
      await db.projectsDao.setActivity(projectId: "/tmp/proj/deleted-only", createdAt: 1, updatedAt: 1);

      final result = await repo.getProjects();

      expect(result.map((p) => p.id), contains("/tmp/proj/alpha"));
      expect(result.map((p) => p.id), contains("/tmp/proj/deleted-only"));
      expect(plugin.listAllSessionsCallCount, 0);
    });

    test("project activity evidence ignores tombstoned sessions", () async {
      plugin.sessions = [
        _session("/tmp/proj/deleted-only", id: "gone", created: 10, updated: 20),
      ];
      await db.sessionDao.insertSessionTombstone(
        backendSessionId: "gone",
        pluginId: "codex",
        deletedAt: 1,
      );

      final result = await repo.listProjectActivityEvidence(pluginId: plugin.id);

      expect(result.map((e) => e.projectId), isNot(contains("/tmp/proj/deleted-only")));
    });

    test("derived activity uses the stored native project identity for the same directory", () async {
      const directory = "/tmp/proj/shared";
      const nativeProjectId = "native-project-id";
      await db.projectsDao.recordOpenedProject(
        projectId: nativeProjectId,
        path: directory,
        displayName: null,
        createdAt: 1,
        updatedAt: 2,
      );
      plugin.sessions = [_session(directory, id: "derived-session", created: 10, updated: 20)];

      final service = ProjectActivityService(projectRepository: repo, now: () => 9999);
      addTearDown(service.dispose);
      await service.reconcile(pluginId: plugin.id);

      final rows = await db.projectsDao.getAllProjects();
      expect(rows.map((project) => project.projectId), [nativeProjectId]);
      expect(rows.single.updatedAt, 20);
    });

    test("openProject records an opened folder so an empty project survives the listing", () async {
      final target = await repo.resolveProjectOpenTarget(path: "/tmp/proj/empty");
      await repo.persistOpenedProject(
        target: target,
        activity: const ProjectActivity(createdAt: 1, updatedAt: 2),
      );
      final opened = await repo.mapOpenedProject(target: target);

      expect(opened.id, "/tmp/proj/empty");
      expect(opened.name, "empty");
      expect(
        (await repo.getProjects()).map((p) => p.id),
        contains("/tmp/proj/empty"),
      );
      final row = (await db.select(db.projectsTable).get()).firstWhere((r) => r.projectId == "/tmp/proj/empty");
      expect(row.createdAt, equals(1));
      expect(row.updatedAt, equals(2));
      expect(plugin.receivedKnownDirectories, isNull);
    });

    test("renameProject persists a display-name override applied on the next listing", () async {
      plugin.sessions = [_session("/tmp/proj/alpha", created: 1, updated: 1)];
      await repo.getProjects();
      await db.projectsDao.setActivity(projectId: "/tmp/proj/alpha", createdAt: 10, updatedAt: 20);

      final renamed = await repo.renameProject(projectId: "/tmp/proj/alpha", name: "Renamed Alpha");

      expect(renamed.name, "Renamed Alpha");
      expect(renamed.time, const ProjectTime(created: 10, updated: 20));
      final listed = (await repo.getProjects()).firstWhere(
        (p) => p.id == "/tmp/proj/alpha",
      );
      expect(listed.name, "Renamed Alpha");
    });

    test("getProject resolves a derived project without calling the plugin's guarded getProject", () async {
      plugin.sessions = [_session("/tmp/proj/alpha", id: "a1", created: 10, updated: 20)];
      await repo.getProjects();
      await db.projectsDao.setActivity(projectId: "/tmp/proj/alpha", createdAt: 30, updatedAt: 40);

      // The mixin's getProject throws; routing through the repository must
      // resolve from the derived set instead of surfacing that as an error.
      final project = await repo.getProject(projectId: "/tmp/proj/alpha");

      expect(project.id, "/tmp/proj/alpha");
      expect(project.name, "alpha");
      expect(project.time, const ProjectTime(created: 30, updated: 40));
    });

    test("derived getProject does not reread activity while finding project metadata", () async {
      plugin.sessions = [_session("/tmp/proj/alpha", id: "a1", created: 10, updated: 20)];
      await db.projectsDao.setActivity(projectId: "/tmp/proj/alpha", createdAt: 30, updatedAt: 40);
      final projectsDao = _CountingProjectsDao(database: db);
      final countingRepo = singlePluginProjectRepository(
        gitCliApi: FakeGitCliApi(),
        plugin: plugin,
        projectsDao: projectsDao,
        sessionDao: db.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
        filesystemApi: FakeFilesystemApi(),
      );

      final project = await countingRepo.getProject(projectId: "/tmp/proj/alpha");

      expect(project.time, const ProjectTime(created: 30, updated: 40));
      expect(projectsDao.getProjectCallCount, 1);
    });

    test("getProject and renameProject reject an unknown derived project id", () async {
      await expectLater(
        () => repo.renameProject(projectId: "/tmp/proj/ghost", name: "Ghost Renamed"),
        throwsA(isA<ProjectNotFoundException>()),
      );
      await expectLater(
        () => repo.getProject(projectId: "/tmp/proj/ghost"),
        throwsA(isA<ProjectNotFoundException>()),
      );

      expect(await db.projectsDao.getProject(projectId: "/tmp/proj/ghost"), isNull);
    });

    test("a session in a dedicated worktree folds into its parent project, not its own card", () async {
      const parent = "/tmp/proj/alpha";
      const worktree = "/tmp/proj/alpha/.worktrees/session-001";
      // The bridge recorded this session under its parent project with the
      // worktree path it created — mirroring SessionCreationService.
      await db.projectsDao.insertProjectsIfMissing(projectIds: [parent]);
      final persistedActivity = await db.projectsDao.getProject(projectId: parent);
      await db.sessionDao.insertSession(
        sessionId: "w1",
        backendSessionId: "w1",
        projectId: parent,
        isDedicated: true,
        createdAt: 200,
        worktreePath: worktree,
        branchName: "session-001",
        baseBranch: "main",
        baseCommit: "abc123",
        lastAgent: null,
        lastAgentModel: null,
        pluginId: "codex",
      );
      // The plugin, however, only knows the session by its worktree cwd.
      plugin.sessions = [
        _session(parent, id: "s1", created: 100, updated: 100),
        _session(worktree, id: "w1", created: 200, updated: 200),
      ];

      final result = await repo.getProjects();

      // One card (the parent), never a card named after the worktree.
      expect(result.map((p) => p.id).toSet(), {parent});
      // Session timestamps remain reconciliation evidence. Listing preserves
      // the existing persisted timestamp.
      expect(result.single.time?.updated, persistedActivity!.updatedAt);
    });

    test("getProjects does not probe derived project directories", () async {
      plugin.sessions = [
        _session("/tmp/proj/alpha", id: "a1", created: 1, updated: 2),
        _session("/tmp/proj/beta", id: "b1", created: 1, updated: 1),
      ];
      final repoWithMissing = singlePluginProjectRepository(
        gitCliApi: FakeGitCliApi(),
        plugin: plugin,
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
        filesystemApi: FakeFilesystemApi(missingPaths: {"/tmp/proj/beta"}),
      );
      await db.projectsDao.setActivity(
        projectId: "/tmp/proj/alpha",
        createdAt: 1,
        updatedAt: 2,
      );
      await db.projectsDao.setActivity(
        projectId: "/tmp/proj/beta",
        createdAt: 1,
        updatedAt: 1,
      );

      final result = await repoWithMissing.getProjects();

      expect(result.firstWhere((p) => p.id == "/tmp/proj/alpha").directoryMissing, isFalse);
      expect(result.firstWhere((p) => p.id == "/tmp/proj/beta").directoryMissing, isFalse);
    });
  });

  group("ProjectRepository getRemoteIdentity", () {
    late AppDatabase db;
    late _FakeBridgePlugin plugin;

    setUp(() {
      db = createTestDatabase();
      plugin = _FakeBridgePlugin();
    });

    tearDown(() async {
      await db.close();
    });

    ProjectRepository repoWith({required String? remoteUrl}) => singlePluginProjectRepository(
      gitCliApi: FakeGitCliApi(remoteUrl: remoteUrl),
      plugin: plugin,
      projectsDao: db.projectsDao,
      sessionDao: db.sessionDao,
      unseenCalculator: const SessionUnseenCalculator(),
      filesystemApi: FakeFilesystemApi(),
    );

    test("returns null for a project with no stored row", () async {
      final repo = repoWith(remoteUrl: "git@github.com:org/repo.git");

      expect(await repo.getRemoteIdentity(projectId: "unknown"), isNull);
    });

    test("returns null when the project has no usable remote", () async {
      await db.projectsDao.recordOpenedProject(
        projectId: "/dev/app",
        path: "/dev/app",
        displayName: null,
        createdAt: 1,
        updatedAt: 1,
      );
      final repo = repoWith(remoteUrl: null);

      expect(await repo.getRemoteIdentity(projectId: "/dev/app"), isNull);
    });

    test("parses the remote URL of the stored project path into host and slug", () async {
      await db.projectsDao.recordOpenedProject(
        projectId: "/dev/app",
        path: "/dev/app",
        displayName: null,
        createdAt: 1,
        updatedAt: 1,
      );
      final repo = repoWith(remoteUrl: "git@github.com:sesori-ai/sesori.git");

      expect(
        await repo.getRemoteIdentity(projectId: "/dev/app"),
        equals((host: "github.com", slug: "sesori-ai/sesori")),
      );
    });

    test("returns null for a local filesystem remote", () async {
      await db.projectsDao.recordOpenedProject(
        projectId: "/dev/app",
        path: "/dev/app",
        displayName: null,
        createdAt: 1,
        updatedAt: 1,
      );
      final repo = repoWith(remoteUrl: "/srv/git/repo.git");

      expect(await repo.getRemoteIdentity(projectId: "/dev/app"), isNull);
    });
  });
}

PluginSession _session(
  String directory, {
  String id = "s",
  required int created,
  required int updated,
}) {
  return PluginSession(
    id: id,
    projectID: directory,
    directory: directory,
    parentID: null,
    title: null,
    time: PluginSessionTime(created: created, updated: updated, archived: null),
  );
}

/// Minimal [BridgePluginApi] fake that only implements the surface touched by
/// [ProjectRepository]. Every other member throws so accidental use is loud.
class _FakeBridgePlugin implements NativeProjectsPluginApi {
  List<PluginProject> projectsResult = const [];
  Future<List<PluginProject>>? getProjectsFuture;
  Object? getProjectsError;
  PluginProject projectResult = const PluginProject(id: "project-id", directory: "project-id");
  String? lastGetProjectId;
  String? lastRenameProjectId;
  int getProjectsCallCount = 0;

  @override
  Future<List<PluginProject>> getProjects() async {
    getProjectsCallCount++;
    if (getProjectsFuture case final future?) return future;
    final err = getProjectsError;
    if (err != null) throw err;
    return projectsResult;
  }

  @override
  String get id => "fake";

  @override
  Stream<BridgeSseEvent> get events => throw UnimplementedError();

  @override
  Future<List<PluginSession>> getSessions(String projectId, {int? start, int? limit}) => throw UnimplementedError();

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) => throw UnimplementedError();

  @override
  Future<PluginSession> renameSession({required String sessionId, required String title}) => throw UnimplementedError();

  @override
  Future<PluginProject> renameProject({required String projectId, required String name}) async {
    lastRenameProjectId = projectId;
    return projectResult;
  }

  @override
  Future<void> deleteSession(String sessionId) => throw UnimplementedError();

  @override
  Future<void> archiveSession({required String sessionId}) => throw UnimplementedError();

  @override
  Future<void> deleteWorkspace({
    required String projectId,
    required String worktreePath,
  }) => throw UnimplementedError();

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) => throw UnimplementedError();

  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() => throw UnimplementedError();

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId) => throw UnimplementedError();

  @override
  Future<List<PluginCommand>> getCommands({required String? projectId}) async => <PluginCommand>[];

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) => throw UnimplementedError();

  @override
  Future<void> sendCommand({
    required String sessionId,
    required String command,
    required String arguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {}

  @override
  Future<void> abortSession({required String sessionId}) => throw UnimplementedError();

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) => throw UnimplementedError();

  @override
  Future<List<PluginPendingPermission>> getPendingPermissions({required String sessionId}) async => [];

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({required String sessionId}) => throw UnimplementedError();

  @override
  Future<List<PluginPendingQuestion>> getProjectQuestions({required String projectId}) => throw UnimplementedError();

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) => throw UnimplementedError();

  @override
  Future<void> rejectQuestion({required String questionId, required String? sessionId}) => throw UnimplementedError();

  @override
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) => throw UnimplementedError();

  @override
  Future<PluginProject> getProject(String projectId) async {
    lastGetProjectId = projectId;
    return projectResult;
  }

  @override
  Future<bool> healthCheck() => throw UnimplementedError();

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) => throw UnimplementedError();

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => throw UnimplementedError();

  @override
  Future<void> dispose() => throw UnimplementedError();
}

/// A derive-style plugin: exposes its sessions through
/// [BridgeDerivedProjectsPluginApi.listAllSessions], mirroring how Codex/ACP
/// plugins are shaped — it has no project members at all, so the bridge
/// derivation path is what's exercised.
class _FakeDerivedPlugin implements BridgeDerivedProjectsPluginApi {
  _FakeDerivedPlugin(this.sessions);

  List<PluginSession> sessions;

  /// Points at a session directory used by the tests so the launch-folder seed
  /// doesn't introduce an extra project the assertions don't expect.
  String launchDir = "/tmp/proj/alpha";

  /// The hint set received on the most recent [listAllSessions] call.
  Set<String>? receivedKnownDirectories;
  int listAllSessionsCallCount = 0;

  @override
  String get id => "codex";

  @override
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async {
    listAllSessionsCallCount++;
    receivedKnownDirectories = knownDirectories;
    return sessions;
  }

  @override
  String get launchDirectory => launchDir;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CountingProjectsDao extends ProjectsDao {
  _CountingProjectsDao({required AppDatabase database}) : super(database);

  int getAllProjectsCallCount = 0;
  int getProjectCallCount = 0;
  int getCatalogProjectsCallCount = 0;

  @override
  Future<List<ProjectDto>> getCatalogProjects() {
    getCatalogProjectsCallCount++;
    return super.getCatalogProjects();
  }

  @override
  Future<List<ProjectDto>> getAllProjects() {
    getAllProjectsCallCount++;
    return super.getAllProjects();
  }

  @override
  Future<ProjectDto?> getProject({required String projectId}) {
    getProjectCallCount++;
    return super.getProject(projectId: projectId);
  }
}
