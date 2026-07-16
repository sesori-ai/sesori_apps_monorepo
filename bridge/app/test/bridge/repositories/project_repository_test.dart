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
import "../../helpers/test_database.dart";

void main() {
  group("ProjectRepository", () {
    late AppDatabase db;
    late _FakeBridgePlugin plugin;
    late ProjectRepository repo;

    setUp(() {
      db = createTestDatabase();
      plugin = _FakeBridgePlugin();
      repo = ProjectRepository(
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

    test("getProjects fetches plugin projects, persists each, filters hidden, sorts by updated desc", () async {
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

      final result = await repo.getProjects(defaultTimestamp: 9999);

      // (a) DB has all 3 rows (every plugin project is persisted regardless
      //     of hidden status — the FK target must always exist).
      final rows = await db.select(db.projectsTable).get();
      expect(
        rows.map((r) => r.projectId).toSet(),
        equals({"p1", "p2", "p3"}),
        reason: "every plugin project must be upserted into projects_table",
      );

      // (b) Returned list filters p2 out.
      expect(result, hasLength(2));

      // (c) Order is [p3, p1] — sorted by persisted updatedAt descending.
      expect(result.map((p) => p.id).toList(), equals(["p3", "p1"]));
    });

    test("getProjects persists a native project's declared directory instead of its id", () async {
      plugin.projectsResult = const [
        PluginProject(id: "backend-project-1", directory: "/projects/one", name: "One"),
      ];

      final result = await repo.getProjects(defaultTimestamp: 9999);

      expect(result.single.id, "backend-project-1");
      expect(result.single.path, "/projects/one");
      expect(
        (await db.projectsDao.getProject(projectId: "backend-project-1"))!.path,
        "/projects/one",
      );
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
        createdAt: 1,
        updatedAt: 1,
      );
      final service = ProjectActivityService(projectRepository: repo, now: () => 9999);
      addTearDown(service.dispose);

      await service.reconcile();

      final newProject = await db.projectsDao.getProject(projectId: "new-project");
      expect(newProject?.path, "/projects/new");
      expect(newProject?.createdAt, 10);
      expect(newProject?.updatedAt, 20);
      expect((await db.projectsDao.getProject(projectId: "moved-project"))?.path, "/projects/moved");
    });

    test("getProjects rethrows PluginApiException when plugin throws", () async {
      plugin.getProjectsError = PluginApiException("/project", 500);

      await expectLater(
        () => repo.getProjects(defaultTimestamp: 9999),
        throwsA(isA<PluginApiException>()),
      );

      // Plugin failed before the transaction opened — no rows should be
      // present in the database.
      final rows = await db.select(db.projectsTable).get();
      expect(rows, isEmpty, reason: "no DB writes on plugin failure");
    });

    test("getProjects inserts all projects atomically via batch", () async {
      // Verify that all N plugin projects are persisted in a single batch call.
      // The batch API is internally atomic — all rows land or none do.
      plugin.projectsResult = const [
        PluginProject(id: "p1", directory: "p1"),
        PluginProject(id: "p2", directory: "p2"),
        PluginProject(id: "p3", directory: "p3"),
        PluginProject(id: "p4", directory: "p4"),
      ];

      await repo.getProjects(defaultTimestamp: 9999);

      final rows = await db.select(db.projectsTable).get();
      expect(
        rows.map((r) => r.projectId).toSet(),
        equals({"p1", "p2", "p3", "p4"}),
        reason: "all plugin projects must be persisted via batch insert",
      );
    });

    test("getProjects seeds direct activity and one now default for missing evidence", () async {
      plugin.projectsResult = const [
        PluginProject(
          id: "direct",
          directory: "direct",
          activity: PluginProjectActivity(createdAt: 10, updatedAt: 20),
        ),
        PluginProject(id: "default", directory: "default"),
      ];

      final result = await repo.getProjects(defaultTimestamp: 1234);
      final rows = {for (final row in await db.projectsDao.getAllProjects()) row.projectId: row};

      expect(rows["direct"]!.createdAt, 10);
      expect(rows["direct"]!.updatedAt, 20);
      expect(rows["default"]!.createdAt, 1234);
      expect(rows["default"]!.updatedAt, 1234);
      expect(result.every((project) => project.time != null), isTrue);
    });

    test("getProjects reuses one post-seed project snapshot for paths and activity", () async {
      plugin.projectsResult = const [
        PluginProject(
          id: "new",
          directory: "new",
          activity: PluginProjectActivity(createdAt: 10, updatedAt: 20),
        ),
      ];
      final projectsDao = _CountingProjectsDao(database: db);
      final countingRepo = ProjectRepository(
        plugin: plugin,
        projectsDao: projectsDao,
        sessionDao: db.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
        filesystemApi: FakeFilesystemApi(),
      );

      final result = await countingRepo.getProjects(defaultTimestamp: 9999);

      expect(projectsDao.getAllProjectsCallCount, 1);
      expect(result.single.time, const ProjectTime(created: 10, updated: 20));
    });

    test("getProjects sorts equal timestamps by name and then id", () async {
      plugin.projectsResult = const [
        PluginProject(id: "z", directory: "z", name: "Beta"),
        PluginProject(id: "b", directory: "b", name: "Alpha"),
        PluginProject(id: "a", directory: "a", name: "Alpha"),
      ];
      for (final id in ["z", "b", "a"]) {
        await db.projectsDao.setActivity(projectId: id, createdAt: 1, updatedAt: 10);
      }

      final result = await repo.getProjects(defaultTimestamp: 9999);

      expect(result.map((project) => project.id), ["a", "b", "z"]);
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
        projectId: target.projectId,
        path: target.path,
        activity: const ProjectActivity(createdAt: 1, updatedAt: 2),
      );
      final result = await repo.mapOpenedProject(target: target);

      expect(plugin.lastGetProjectId, equals("/tmp/p-open"));
      expect(result.id, equals("p-open"));
      expect(result.name, equals("Opened"));
      final hiddenIds = await db.projectsDao.getHiddenProjectIds();
      expect(hiddenIds, isNot(contains("p-open")));
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
          projectId: target.projectId,
          path: target.path,
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
          projectId: target.projectId,
          path: target.path,
          activity: const ProjectActivity(createdAt: 0, updatedAt: 1),
        );

        final result = await repo.getProjects(defaultTimestamp: 9999);

        expect(result, hasLength(1));
        expect(result.single.id, equals("/projects/a"));
        expect(result.single.path, equals("/moved/a"));
      });

      test("getProjects computes directoryMissing against the live path, not the id", () async {
        plugin.projectResult = const PluginProject(id: "/projects/a", directory: "/moved/a", name: "A");
        plugin.projectsResult = const [
          PluginProject(id: "/projects/a", directory: "/projects/a", name: "A"),
        ];
        final repoWithMissing = ProjectRepository(
          plugin: plugin,
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
          unseenCalculator: const SessionUnseenCalculator(),
          // The original location is gone; the folder lives at /moved/a now.
          filesystemApi: FakeFilesystemApi(missingPaths: {"/projects/a"}),
        );
        final target = await repoWithMissing.resolveProjectOpenTarget(path: "/moved/a");
        await repoWithMissing.persistOpenedProject(
          projectId: target.projectId,
          path: target.path,
          activity: const ProjectActivity(createdAt: 0, updatedAt: 1),
        );

        final result = await repoWithMissing.getProjects(defaultTimestamp: 9999);

        expect(result.firstWhere((p) => p.id == "/projects/a").directoryMissing, isFalse);
      });

      test("getProject and renameProject hand the plugin the live path", () async {
        plugin.projectResult = const PluginProject(id: "/projects/a", directory: "/moved/a", name: "A");
        await db.projectsDao.recordOpenedProject(
          projectId: "/projects/a",
          path: "/moved/a",
          createdAt: 0,
          updatedAt: 1,
        );

        final fetched = await repo.getProject(projectId: "/projects/a");
        expect(plugin.lastGetProjectId, equals("/moved/a"));
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

    test("getProjects flags a project whose directory no longer exists on disk", () async {
      plugin.projectsResult = const [
        PluginProject(id: "/present", directory: "/present", name: "Present"),
        PluginProject(id: "/moved", directory: "/moved", name: "Moved"),
      ];
      final repoWithMissing = ProjectRepository(
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

      final result = await repoWithMissing.getProjects(defaultTimestamp: 9999);

      expect(result.firstWhere((p) => p.id == "/present").directoryMissing, isFalse);
      expect(result.firstWhere((p) => p.id == "/moved").directoryMissing, isTrue);
    });

    test("getProject flags a since-deleted directory as missing", () async {
      plugin.projectResult = const PluginProject(id: "/gone", directory: "/gone", name: "Gone");
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/gone"]);
      final repoWithMissing = ProjectRepository(
        plugin: plugin,
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
        filesystemApi: FakeFilesystemApi(missingPaths: {"/gone"}),
      );

      final result = await repoWithMissing.getProject(projectId: "/gone");

      expect(result.directoryMissing, isTrue);
    });

    test("a directory whose existence probe throws is treated as present, not missing", () async {
      plugin.projectsResult = const [
        PluginProject(id: "/denied", directory: "/denied", name: "Denied"),
      ];
      final repoWithThrow = ProjectRepository(
        plugin: plugin,
        projectsDao: db.projectsDao,
        sessionDao: db.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
        filesystemApi: FakeFilesystemApi(throwingPaths: {"/denied"}),
      );

      final result = await repoWithThrow.getProjects(defaultTimestamp: 9999);

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
      repo = ProjectRepository(
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

    test("getProjects derives projects from the plugin's sessions, grouped by directory and sorted", () async {
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

      final result = await repo.getProjects(defaultTimestamp: 9999);

      expect(result.map((p) => p.id).toSet(), {"/tmp/proj/alpha", "/tmp/proj/beta"});
      // Canonical rows are persisted so a later session insert has an FK target.
      final rows = await db.select(db.projectsTable).get();
      expect(rows.map((r) => r.projectId).toSet(), containsAll({"/tmp/proj/alpha", "/tmp/proj/beta"}));
      // Sorted by persisted updatedAt descending: alpha (50) before beta (1).
      expect(result.first.id, "/tmp/proj/alpha");
    });

    test("normal listing seeds new derived projects without reconciling session evidence", () async {
      plugin.sessions = [
        _session("/tmp/proj/alpha", id: "a1", created: 20, updated: 30),
        _session("/tmp/proj/alpha", id: "a2", created: 10, updated: 40),
      ];
      final service = ProjectActivityService(projectRepository: repo, now: () => 9999);
      addTearDown(service.dispose);

      final result = await service.getProjects();

      expect(result.single.time, const ProjectTime(created: 9999, updated: 9999));
      final row = await db.projectsDao.getProject(projectId: "/tmp/proj/alpha");
      expect(row?.createdAt, 9999);
      expect(row?.updatedAt, 9999);
    });

    test("getProjects omits a project flagged hidden", () async {
      plugin.sessions = [_session("/tmp/proj/alpha", created: 1, updated: 1)];
      await db.projectsDao.hideProject(projectId: "/tmp/proj/alpha");

      expect(await repo.getProjects(defaultTimestamp: 9999), isEmpty);
    });

    test("getProjects ignores tombstoned sessions in project derivation", () async {
      // The backend has no session deletion, so it keeps enumerating the
      // deleted session — its project must not resurrect from it.
      plugin.sessions = [
        _session("/tmp/proj/alpha", id: "kept", created: 1, updated: 1),
        _session("/tmp/proj/deleted-only", id: "gone", created: 1, updated: 1),
      ];
      await db.sessionDao.insertSessionTombstone(backendSessionId: "gone", pluginId: "codex", deletedAt: 1);

      final result = await repo.getProjects(defaultTimestamp: 1);

      expect(result.map((p) => p.id), contains("/tmp/proj/alpha"));
      expect(result.map((p) => p.id), isNot(contains("/tmp/proj/deleted-only")));
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

      final result = await repo.listProjectActivityEvidence();

      expect(result.evidence.map((e) => e.projectId), isNot(contains("/tmp/proj/deleted-only")));
    });

    test("openProject records an opened folder so an empty project survives the listing", () async {
      final target = await repo.resolveProjectOpenTarget(path: "/tmp/proj/empty");
      await repo.persistOpenedProject(
        projectId: target.projectId,
        path: target.path,
        activity: const ProjectActivity(createdAt: 1, updatedAt: 2),
      );
      final opened = await repo.mapOpenedProject(target: target);

      expect(opened.id, "/tmp/proj/empty");
      expect(opened.name, "empty");
      expect(
        (await repo.getProjects(defaultTimestamp: 9999)).map((p) => p.id),
        contains("/tmp/proj/empty"),
      );
      final row = (await db.select(db.projectsTable).get()).firstWhere((r) => r.projectId == "/tmp/proj/empty");
      expect(row.createdAt, equals(1));
      expect(row.updatedAt, equals(2));
      // The stored rows are also the enumeration hints: a directory-scoped
      // backend (ACP) is pointed at every recorded folder, so opening one makes
      // its pre-existing sessions discoverable on the next enumeration.
      expect(plugin.receivedKnownDirectories, containsAll(<String>["/tmp/proj/empty", plugin.launchDir]));
    });

    test("renameProject persists a display-name override applied on the next listing", () async {
      plugin.sessions = [_session("/tmp/proj/alpha", created: 1, updated: 1)];
      await repo.getProjects(defaultTimestamp: 9999);
      await db.projectsDao.setActivity(projectId: "/tmp/proj/alpha", createdAt: 10, updatedAt: 20);

      final renamed = await repo.renameProject(projectId: "/tmp/proj/alpha", name: "Renamed Alpha");

      expect(renamed.name, "Renamed Alpha");
      expect(renamed.time, const ProjectTime(created: 10, updated: 20));
      final listed = (await repo.getProjects(defaultTimestamp: 9999)).firstWhere(
        (p) => p.id == "/tmp/proj/alpha",
      );
      expect(listed.name, "Renamed Alpha");
    });

    test("getProject resolves a derived project without calling the plugin's guarded getProject", () async {
      plugin.sessions = [_session("/tmp/proj/alpha", id: "a1", created: 10, updated: 20)];
      await repo.getProjects(defaultTimestamp: 9999);
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
      final countingRepo = ProjectRepository(
        plugin: plugin,
        projectsDao: projectsDao,
        sessionDao: db.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
        filesystemApi: FakeFilesystemApi(),
      );

      final project = await countingRepo.getProject(projectId: "/tmp/proj/alpha");

      expect(project.time, const ProjectTime(created: 30, updated: 40));
      expect(projectsDao.getProjectCallCount, 2);
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

      final result = await repo.getProjects(defaultTimestamp: 9999);

      // One card (the parent), never a card named after the worktree.
      expect(result.map((p) => p.id).toSet(), {parent});
      // Session timestamps remain reconciliation evidence. Listing preserves
      // the existing persisted timestamp.
      expect(result.single.time?.updated, persistedActivity!.updatedAt);
    });

    test("getProjects flags a derived project whose directory no longer exists on disk", () async {
      plugin.sessions = [
        _session("/tmp/proj/alpha", id: "a1", created: 1, updated: 2),
        _session("/tmp/proj/beta", id: "b1", created: 1, updated: 1),
      ];
      final repoWithMissing = ProjectRepository(
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

      final result = await repoWithMissing.getProjects(defaultTimestamp: 9999);

      expect(result.firstWhere((p) => p.id == "/tmp/proj/alpha").directoryMissing, isFalse);
      expect(result.firstWhere((p) => p.id == "/tmp/proj/beta").directoryMissing, isTrue);
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
  Object? getProjectsError;
  PluginProject projectResult = const PluginProject(id: "project-id", directory: "project-id");
  String? lastGetProjectId;
  String? lastRenameProjectId;

  @override
  Future<List<PluginProject>> getProjects() async {
    final err = getProjectsError;
    if (err != null) throw err;
    return projectsResult;
  }

  @override
  String get id => throw UnimplementedError();

  @override
  bool get supportsIdentityPreservingRowlessChildSessions => false;

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

  @override
  String get id => "codex";

  @override
  Future<List<PluginSession>> listAllSessions({required Set<String> knownDirectories}) async {
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
