import "dart:async";
import "dart:io";

import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/repositories/branch_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/worktree_repository.dart";
import "package:sesori_bridge/src/bridge/routing/update_session_archive_status_handler.dart";
import "package:sesori_bridge/src/bridge/services/session_archive_status_service.dart";
import "package:sesori_bridge/src/bridge/services/session_persistence_service.dart";
import "package:sesori_bridge/src/bridge/services/worktree_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("UpdateSessionArchiveStatusHandler", () {
    late AppDatabase db;
    late FakeBridgePlugin plugin;
    late _FakeWorktreeService worktreeService;
    late SessionArchiveStatusService archiveStatusService;
    late UpdateSessionArchiveStatusHandler handler;

    setUp(() {
      db = createTestDatabase();
      plugin = FakeBridgePlugin();
      worktreeService = _FakeWorktreeService(database: db);
      archiveStatusService = SessionArchiveStatusService(
        plugin: plugin,
        worktreeService: worktreeService,
        sessionRepository: SessionRepository(
          plugin: plugin,
          sessionDao: db.sessionDao,
          pullRequestRepository: PullRequestRepository(
            pullRequestDao: db.pullRequestDao,
            projectsDao: db.projectsDao,
          ),
        ),
        sessionPersistenceService: SessionPersistenceService(
          projectsDao: db.projectsDao,
          sessionDao: db.sessionDao,
          db: db,
        ),
      );
      handler = UpdateSessionArchiveStatusHandler(
        archiveStatusService: archiveStatusService,
      );
    });

    tearDown(() async {
      await plugin.close();
      await db.close();
    });

    test("canHandle PATCH /session/update/archive", () {
      expect(handler.canHandle(makeRequest("PATCH", "/session/update/archive")), isTrue);
    });

    test("does not handle GET /session/update/archive", () {
      expect(handler.canHandle(makeRequest("GET", "/session/update/archive")), isFalse);
    });

    test("throws 400 on empty session id", () async {
      expect(
        () => handler.handle(
          makeRequest("PATCH", "/session/update/archive"),
          body: const UpdateSessionArchiveRequest(
            sessionId: "",
            archived: true,
            deleteWorktree: false,
            deleteBranch: false,
            force: false,
          ),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    test("archive without cleanup sets archivedAt and skips git cleanup", () async {
      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        isDedicated: true,
        worktreePath: "/repo/.worktrees/session-001",
        branchName: "session-001",
        baseBranch: null,
        archivedAt: null,
        baseCommit: null,
      );
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "/repo",
          directory: "/repo/.worktrees/session-001",
          parentID: null,
          title: "Session 1",
          time: PluginSessionTime(created: 10, updated: 20, archived: null),
          summary: null,
        ),
      ];

      final result = await handler.handle(
        makeRequest("PATCH", "/session/update/archive"),
        body: _archiveRequest(
          sessionId: "s1",
          archived: true,
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final persisted = await db.sessionDao.getSession(sessionId: "s1");
      expect(persisted?.archivedAt, isNotNull);
      expect(result.id, equals("s1"));
      expect(result.time?.archived, equals(persisted?.archivedAt));
    });

    test("archive with cleanup on clean worktree removes worktree", () async {
      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        isDedicated: true,
        worktreePath: "/repo/.worktrees/session-001",
        branchName: "session-001",
        baseBranch: null,
        archivedAt: null,
        baseCommit: null,
      );
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "/repo",
          directory: "/repo/.worktrees/session-001",
          parentID: null,
          title: "Session 1",
          time: PluginSessionTime(created: 10, updated: 20, archived: null),
          summary: null,
        ),
      ];

      await handler.handle(
        makeRequest("PATCH", "/session/update/archive"),
        body: _archiveRequest(
          sessionId: "s1",
          archived: true,
          deleteWorktree: true,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final persisted = await db.sessionDao.getSession(sessionId: "s1");
      expect(persisted?.archivedAt, isNotNull);
    });

    test("archive with cleanup on dirty worktree throws 409", () async {
      // Create a real temp directory so checkWorktreeSafety detects it as existing
      final tempDir = Directory.systemTemp.createTempSync("archive_dirty_test");
      final worktreePath = "${tempDir.path}/.worktrees/session-001";
      Directory(worktreePath).createSync(recursive: true);
      addTearDown(() => tempDir.deleteSync(recursive: true));

      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: tempDir.path,
        isDedicated: true,
        worktreePath: worktreePath,
        branchName: "session-001",
        baseBranch: null,
        archivedAt: null,
        baseCommit: null,
      );

      await expectLater(
        () => handler.handle(
          makeRequest("PATCH", "/session/update/archive"),
          body: _archiveRequest(
            sessionId: "s1",
            archived: true,
            deleteWorktree: true,
            deleteBranch: false,
            force: false,
          ),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(409))),
      );

      final persisted = await db.sessionDao.getSession(sessionId: "s1");
      expect(persisted?.archivedAt, isNull);
    });

    test("archive with shared worktree returns structured 409 rejection payload", () async {
      await _insertSession(
        db: db,
        sessionId: "s-shared-1",
        projectId: "/repo",
        isDedicated: true,
        worktreePath: "/repo/.worktrees/session-shared",
        branchName: "session-shared",
        baseBranch: "main",
        archivedAt: null,
        baseCommit: "abc123",
      );
      await _insertSession(
        db: db,
        sessionId: "s-shared-2",
        projectId: "/repo",
        isDedicated: true,
        worktreePath: "/repo/.worktrees/session-shared",
        branchName: "session-shared",
        baseBranch: "main",
        archivedAt: null,
        baseCommit: "abc123",
      );

      await expectLater(
        () => handler.handle(
          makeRequest("PATCH", "/session/update/archive"),
          body: _archiveRequest(
            sessionId: "s-shared-1",
            archived: true,
            deleteWorktree: true,
            deleteBranch: true,
            force: false,
          ),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(
          isA<RelayResponse>()
              .having((response) => response.status, "status", equals(409))
              .having(
                (response) => response.headers["content-type"],
                "content-type",
                equals("application/json"),
              )
              .having(
                (response) {
                  final rejection = SessionCleanupRejection.fromJson(
                    jsonDecodeMap(response.body.toString()),
                  );
                  return rejection.issues;
                },
                "issues",
                equals(const [CleanupIssue.sharedWorktree()]),
              ),
        ),
      );

      final persisted = await db.sessionDao.getSession(sessionId: "s-shared-1");
      expect(persisted?.archivedAt, isNull);
    });

    test("archive with force skips safety check", () async {
      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        isDedicated: true,
        worktreePath: "/repo/.worktrees/session-001",
        branchName: "session-001",
        baseBranch: null,
        archivedAt: null,
        baseCommit: null,
      );
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "/repo",
          directory: "/repo/.worktrees/session-001",
          parentID: null,
          title: "Session 1",
          time: PluginSessionTime(created: 10, updated: 20, archived: null),
          summary: null,
        ),
      ];

      await handler.handle(
        makeRequest("PATCH", "/session/update/archive"),
        body: _archiveRequest(
          sessionId: "s1",
          archived: true,
          deleteWorktree: true,
          deleteBranch: false,
          force: true,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
    });

    test("unarchive with existing worktree clears archivedAt", () async {
      final existingDir = Directory.systemTemp.createTempSync("archive-handler-");
      addTearDown(() {
        if (existingDir.existsSync()) {
          existingDir.deleteSync(recursive: true);
        }
      });

      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        isDedicated: true,
        worktreePath: existingDir.path,
        branchName: "session-001",
        baseBranch: null,
        archivedAt: 123,
        baseCommit: null,
      );
      plugin.sessionsResult = [
        PluginSession(
          id: "s1",
          projectID: "/repo",
          directory: existingDir.path,
          parentID: null,
          title: "Session 1",
          time: const PluginSessionTime(created: 10, updated: 20, archived: 123),
          summary: null,
        ),
      ];

      final result = await handler.handle(
        makeRequest("PATCH", "/session/update/archive"),
        body: _archiveRequest(
          sessionId: "s1",
          archived: false,
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final persisted = await db.sessionDao.getSession(sessionId: "s1");
      expect(persisted?.archivedAt, isNull);
      expect(result.time?.archived, isNull);
    });

    test("unarchive with deleted worktree restores worktree", () async {
      final deletedWorktreePath = "${Directory.systemTemp.path}/missing-worktree-s1";
      final deletedWorktree = Directory(deletedWorktreePath);
      if (deletedWorktree.existsSync()) {
        deletedWorktree.deleteSync(recursive: true);
      }

      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        isDedicated: true,
        worktreePath: deletedWorktreePath,
        branchName: "session-001",
        baseBranch: null,
        archivedAt: 123,
        baseCommit: null,
      );
      plugin.sessionsResult = [
        PluginSession(
          id: "s1",
          projectID: "/repo",
          directory: deletedWorktreePath,
          parentID: null,
          title: "Session 1",
          time: const PluginSessionTime(created: 10, updated: 20, archived: 123),
          summary: null,
        ),
      ];

      await handler.handle(
        makeRequest("PATCH", "/session/update/archive"),
        body: _archiveRequest(
          sessionId: "s1",
          archived: false,
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final persisted = await db.sessionDao.getSession(sessionId: "s1");
      expect(persisted?.archivedAt, isNull);
    });

    test("unarchive with blank restore metadata falls back to main and null commit", () async {
      final deletedWorktreePath = "${Directory.systemTemp.path}/missing-worktree-blank-base";
      final deletedWorktree = Directory(deletedWorktreePath);
      if (deletedWorktree.existsSync()) {
        deletedWorktree.deleteSync(recursive: true);
      }

      await _insertSession(
        db: db,
        sessionId: "s-blank-base",
        projectId: "/repo",
        isDedicated: true,
        worktreePath: deletedWorktreePath,
        branchName: "session-blank-base",
        baseBranch: "",
        archivedAt: 123,
        baseCommit: "   ",
      );
      plugin.sessionsResult = [
        PluginSession(
          id: "s-blank-base",
          projectID: "/repo",
          directory: deletedWorktreePath,
          parentID: null,
          title: "Blank Base Session",
          time: const PluginSessionTime(created: 10, updated: 20, archived: 123),
          summary: null,
        ),
      ];

      await handler.handle(
        makeRequest("PATCH", "/session/update/archive"),
        body: _archiveRequest(
          sessionId: "s-blank-base",
          archived: false,
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(worktreeService.restoreCallCount, equals(1));
      expect(worktreeService.lastRestoreBaseBranch, equals("main"));
      expect(worktreeService.lastRestoreBaseCommit, isNull);
    });

    test("archive pre-migration session auto-inserts DB row", () async {
      plugin.projectsResult = const [PluginProject(id: "/repo")];
      plugin.sessionsResult = const [
        PluginSession(
          id: "s-pre-migration",
          projectID: "/repo",
          directory: "/repo/.worktrees/session-001",
          parentID: null,
          title: "Pre-migration Session",
          time: PluginSessionTime(created: 10, updated: 20, archived: null),
          summary: null,
        ),
      ];

      // Seed the project row to satisfy the v5 FK constraint before the handler
      // auto-inserts the session row.
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/repo"]);

      await handler.handle(
        makeRequest("PATCH", "/session/update/archive"),
        body: _archiveRequest(
          sessionId: "s-pre-migration",
          archived: true,
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final persisted = await db.sessionDao.getSession(sessionId: "s-pre-migration");
      expect(persisted, isNotNull);
      expect(persisted?.projectId, equals("/repo"));
      expect(persisted?.isDedicated, isFalse);
      expect(persisted?.worktreePath, isNull);
      expect(persisted?.branchName, isNull);
      expect(persisted?.baseBranch, isNull);
      expect(persisted?.baseCommit, isNull);
      expect(persisted?.archivedAt, isNotNull);
    });

    test("unarchive pre-migration session auto-inserts non-dedicated row and skips restore", () async {
      plugin.projectsResult = const [PluginProject(id: "/repo")];
      plugin.sessionsResult = const [
        PluginSession(
          id: "s-pre-migration-unarchive",
          projectID: "/repo",
          directory: "/repo",
          parentID: null,
          title: "Pre-migration Session",
          time: PluginSessionTime(created: 10, updated: 20, archived: 123),
          summary: null,
        ),
      ];

      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/repo"]);

      final result = await handler.handle(
        makeRequest("PATCH", "/session/update/archive"),
        body: _archiveRequest(
          sessionId: "s-pre-migration-unarchive",
          archived: false,
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final persisted = await db.sessionDao.getSession(sessionId: "s-pre-migration-unarchive");
      expect(result.id, equals("s-pre-migration-unarchive"));
      expect(result.time?.archived, isNull);
      expect(persisted, isNotNull);
      expect(persisted?.projectId, equals("/repo"));
      expect(persisted?.isDedicated, isFalse);
      expect(persisted?.worktreePath, isNull);
      expect(persisted?.branchName, isNull);
      expect(persisted?.baseBranch, isNull);
      expect(persisted?.baseCommit, isNull);
      expect(persisted?.archivedAt, isNull);
      expect(worktreeService.restoreCallCount, equals(0));
    });

    test("archives first-time project (no prior projects_table row) without FK violation", () async {
      // Empty projects_table — no pre-seeding at all.
      plugin.projectsResult = const [PluginProject(id: "brand-new")];
      plugin.sessionsResult = const [
        PluginSession(
          id: "s-brand-new",
          projectID: "brand-new",
          directory: "brand-new",
          parentID: null,
          title: "Brand New Session",
          time: PluginSessionTime(created: 10, updated: 20, archived: null),
          summary: null,
        ),
      ];

      // Should not throw FK violation even though projects_table is empty.
      await handler.handle(
        makeRequest("PATCH", "/session/update/archive"),
        body: _archiveRequest(
          sessionId: "s-brand-new",
          archived: true,
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final persisted = await db.sessionDao.getSession(sessionId: "s-brand-new");
      expect(persisted, isNotNull);
      expect(persisted?.projectId, equals("brand-new"));
      expect(persisted?.archivedAt, isNotNull);
    });

    test("unarchive simple session clears archivedAt without worktree ops", () async {
      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        isDedicated: false,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        archivedAt: 123,
        baseCommit: null,
      );
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "/repo",
          directory: "/repo",
          parentID: null,
          title: "Simple Session",
          time: PluginSessionTime(created: 10, updated: 20, archived: 123),
          summary: null,
        ),
      ];

      await handler.handle(
        makeRequest("PATCH", "/session/update/archive"),
        body: _archiveRequest(
          sessionId: "s1",
          archived: false,
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final persisted = await db.sessionDao.getSession(sessionId: "s1");
      expect(persisted?.archivedAt, isNull);
    });

    test("archive fires plugin archiveSession", () async {
      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        isDedicated: false,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        archivedAt: null,
        baseCommit: null,
      );
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "/repo",
          directory: "/repo",
          parentID: null,
          title: "Session 1",
          time: PluginSessionTime(created: 10, updated: 20, archived: null),
          summary: null,
        ),
      ];

      await handler.handle(
        makeRequest("PATCH", "/session/update/archive"),
        body: _archiveRequest(
          sessionId: "s1",
          archived: true,
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      // Fire-and-forget — give the microtask a chance to run.
      await Future<void>.delayed(Duration.zero);
      expect(plugin.lastArchiveSessionId, equals("s1"));
    });

    test("unarchive does not fire plugin archiveSession", () async {
      final existingDir = Directory.systemTemp.createTempSync("archive-handler-");
      addTearDown(() {
        if (existingDir.existsSync()) {
          existingDir.deleteSync(recursive: true);
        }
      });

      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        isDedicated: true,
        worktreePath: existingDir.path,
        branchName: "session-001",
        baseBranch: null,
        archivedAt: 123,
        baseCommit: null,
      );
      plugin.sessionsResult = [
        PluginSession(
          id: "s1",
          projectID: "/repo",
          directory: existingDir.path,
          parentID: null,
          title: "Session 1",
          time: const PluginSessionTime(created: 10, updated: 20, archived: 123),
          summary: null,
        ),
      ];

      await handler.handle(
        makeRequest("PATCH", "/session/update/archive"),
        body: _archiveRequest(
          sessionId: "s1",
          archived: false,
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      await Future<void>.delayed(Duration.zero);
      expect(plugin.lastArchiveSessionId, isNull);
    });

    test("archive succeeds even when plugin archiveSession throws", () async {
      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        isDedicated: false,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        archivedAt: null,
        baseCommit: null,
      );
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "/repo",
          directory: "/repo",
          parentID: null,
          title: "Session 1",
          time: PluginSessionTime(created: 10, updated: 20, archived: null),
          summary: null,
        ),
      ];
      plugin.throwOnArchiveSessionError = Exception("OpenCode unavailable");

      final result = await handler.handle(
        makeRequest("PATCH", "/session/update/archive"),
        body: _archiveRequest(
          sessionId: "s1",
          archived: true,
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final persisted = await db.sessionDao.getSession(sessionId: "s1");
      expect(persisted?.archivedAt, isNotNull);
      expect(result.time?.archived, equals(persisted?.archivedAt));
    });

    test("archive does not await plugin archiveSession", () async {
      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        isDedicated: false,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        archivedAt: null,
        baseCommit: null,
      );
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "/repo",
          directory: "/repo",
          parentID: null,
          title: "Session 1",
          time: PluginSessionTime(created: 10, updated: 20, archived: null),
          summary: null,
        ),
      ];
      // Plugin never completes — if handler awaited, this test would hang.
      plugin.archiveSessionCompleter = Completer<void>();

      final result = await handler.handle(
        makeRequest("PATCH", "/session/update/archive"),
        body: _archiveRequest(
          sessionId: "s1",
          archived: true,
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.id, equals("s1"));
      expect(result.time?.archived, isNotNull);
    });

    test("archive simple session sets archivedAt and skips cleanup", () async {
      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        isDedicated: false,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        archivedAt: null,
        baseCommit: null,
      );
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "/repo",
          directory: "/repo",
          parentID: null,
          title: "Simple Session",
          time: PluginSessionTime(created: 10, updated: 20, archived: null),
          summary: null,
        ),
      ];

      await handler.handle(
        makeRequest("PATCH", "/session/update/archive"),
        body: _archiveRequest(
          sessionId: "s1",
          archived: true,
          deleteWorktree: true,
          deleteBranch: true,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      final persisted = await db.sessionDao.getSession(sessionId: "s1");
      expect(persisted?.archivedAt, isNotNull);
    });

    test("archive response has hasWorktree true when session has worktreePath", () async {
      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        isDedicated: true,
        worktreePath: "/repo/.worktrees/session-001",
        branchName: "session-001",
        baseBranch: null,
        archivedAt: null,
        baseCommit: null,
      );
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "/repo",
          directory: "/repo/.worktrees/session-001",
          parentID: null,
          title: "Session 1",
          time: PluginSessionTime(created: 10, updated: 20, archived: null),
          summary: null,
        ),
      ];

      final result = await handler.handle(
        makeRequest("PATCH", "/session/update/archive"),
        body: _archiveRequest(
          sessionId: "s1",
          archived: true,
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.hasWorktree, isTrue);
    });

    test("archive response has hasWorktree false when session has no worktreePath", () async {
      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        isDedicated: false,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        archivedAt: null,
        baseCommit: null,
      );
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "/repo",
          directory: "/repo",
          parentID: null,
          title: "Session 1",
          time: PluginSessionTime(created: 10, updated: 20, archived: null),
          summary: null,
        ),
      ];

      final result = await handler.handle(
        makeRequest("PATCH", "/session/update/archive"),
        body: _archiveRequest(
          sessionId: "s1",
          archived: true,
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.hasWorktree, isFalse);
    });

    test("archive response keeps root-checkout branch sessions non-worktree", () async {
      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        isDedicated: false,
        worktreePath: "/repo",
        branchName: "feature-branch",
        baseBranch: null,
        archivedAt: null,
        baseCommit: null,
      );
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "/repo",
          directory: "/repo",
          parentID: null,
          title: "Session 1",
          time: PluginSessionTime(created: 10, updated: 20, archived: null),
          summary: null,
        ),
      ];

      final result = await handler.handle(
        makeRequest("PATCH", "/session/update/archive"),
        body: _archiveRequest(
          sessionId: "s1",
          archived: true,
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.branchName, equals("feature-branch"));
      expect(result.hasWorktree, isFalse);
    });

    test("unarchive response has hasWorktree true when session has worktreePath", () async {
      final existingDir = Directory.systemTemp.createTempSync("archive-handler-worktree-");
      addTearDown(() {
        if (existingDir.existsSync()) {
          existingDir.deleteSync(recursive: true);
        }
      });

      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        isDedicated: true,
        worktreePath: existingDir.path,
        branchName: "session-001",
        baseBranch: null,
        archivedAt: 123,
        baseCommit: null,
      );
      plugin.sessionsResult = [
        PluginSession(
          id: "s1",
          projectID: "/repo",
          directory: existingDir.path,
          parentID: null,
          title: "Session 1",
          time: const PluginSessionTime(created: 10, updated: 20, archived: 123),
          summary: null,
        ),
      ];

      final result = await handler.handle(
        makeRequest("PATCH", "/session/update/archive"),
        body: _archiveRequest(
          sessionId: "s1",
          archived: false,
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.hasWorktree, isTrue);
    });

    test("unarchive response has hasWorktree false when session has no worktreePath", () async {
      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        isDedicated: false,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        archivedAt: 123,
        baseCommit: null,
      );
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "/repo",
          directory: "/repo",
          parentID: null,
          title: "Session 1",
          time: PluginSessionTime(created: 10, updated: 20, archived: 123),
          summary: null,
        ),
      ];

      final result = await handler.handle(
        makeRequest("PATCH", "/session/update/archive"),
        body: _archiveRequest(
          sessionId: "s1",
          archived: false,
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.hasWorktree, isFalse);
    });

    test("session id is preserved on unarchive response", () async {
      await _insertSession(
        db: db,
        sessionId: "s-preserve",
        projectId: "/repo",
        isDedicated: false,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        archivedAt: 123,
        baseCommit: null,
      );
      plugin.sessionsResult = const [
        PluginSession(
          id: "s-preserve",
          projectID: "/repo",
          directory: "/repo",
          parentID: null,
          title: "Preserved",
          time: PluginSessionTime(created: 10, updated: 20, archived: 123),
          summary: null,
        ),
      ];

      final result = await handler.handle(
        makeRequest("PATCH", "/session/update/archive"),
        body: _archiveRequest(
          sessionId: "s-preserve",
          archived: false,
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(result.id, equals("s-preserve"));
      expect(result.time?.archived, isNull);
    });
  });
}

UpdateSessionArchiveRequest _archiveRequest({
  required String sessionId,
  required bool archived,
  required bool deleteWorktree,
  required bool deleteBranch,
  required bool force,
}) {
  return UpdateSessionArchiveRequest(
    sessionId: sessionId,
    archived: archived,
    deleteWorktree: deleteWorktree,
    deleteBranch: deleteBranch,
    force: force,
  );
}

Future<void> _insertSession({
  required AppDatabase db,
  required String sessionId,
  required String projectId,
  required bool isDedicated,
  required String? worktreePath,
  required String? branchName,
  required String? baseBranch,
  required int? archivedAt,
  required String? baseCommit,
}) async {
  await db.projectsDao.insertProjectsIfMissing(projectIds: [projectId]); // satisfy v5 FK constraint
  await db.sessionDao.insertSession(
    sessionId: sessionId,
    projectId: projectId,
    isDedicated: isDedicated,
    createdAt: 1,
    worktreePath: worktreePath,
    branchName: branchName,
    baseBranch: baseBranch,
    baseCommit: baseCommit,
  );
  if (archivedAt != null) {
    await db.sessionDao.setArchived(sessionId: sessionId, archivedAt: archivedAt);
  }
}

class _FakeWorktreeService extends WorktreeService {
  int restoreCallCount = 0;
  String? lastRestoreBaseBranch;
  String? lastRestoreBaseCommit;

  _FakeWorktreeService({required AppDatabase database})
    : super(
        branchRepository: BranchRepository(
          gitCliApi: GitCliApi(processRunner: _FakeProcessRunner(), gitPathExists: ({required String gitPath}) => true),
        ),
        worktreeRepository: WorktreeRepository(
          projectsDao: database.projectsDao,
          sessionDao: database.sessionDao,
          gitApi: GitCliApi(
            processRunner: _FakeProcessRunner(),
            gitPathExists: ({required String gitPath}) => true,
          ),
        ),
      );

  @override
  Future<bool> restoreWorktree({
    required String projectPath,
    required String worktreePath,
    required String branchName,
    required String baseBranch,
    required String? baseCommit,
  }) async {
    restoreCallCount++;
    lastRestoreBaseBranch = baseBranch;
    lastRestoreBaseCommit = baseCommit;
    return true;
  }
}

class _FakeProcessRunner implements ProcessRunner {
  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    // For rev-parse --verify (restoreWorktree): return success so branch exists
    if (arguments.contains("--verify")) {
      return ProcessResult(0, 0, "abc123\n", "");
    }
    return ProcessResult(0, 0, "", "");
  }
}
