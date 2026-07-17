import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/database/tables/pull_requests_table.dart";
import "package:sesori_bridge/src/bridge/api/filesystem_api.dart";
import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/filesystem_permission_validator.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/repositories/filesystem_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/repositories/worktree_repository.dart";
import "package:sesori_bridge/src/bridge/routing/update_session_archive_status_handler.dart";
import "package:sesori_bridge/src/bridge/services/session_lifecycle_service.dart";
import "package:sesori_bridge/src/bridge/services/session_unseen_service.dart";
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
    late SessionUnseenService unseenService;
    late UpdateSessionArchiveStatusHandler handler;

    setUp(() {
      db = createTestDatabase();
      plugin = FakeBridgePlugin();
      worktreeService = _FakeWorktreeService(database: db);
      final sessionRepository = SessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      final filesystemRepository = FilesystemRepository(
        filesystemApi: const FilesystemApi(),
        permissionValidator: const FilesystemPermissionValidator(),
      );
      handler = UpdateSessionArchiveStatusHandler(
        sessionLifecycleService: SessionLifecycleService(
          worktreeService: worktreeService,
          sessionRepository: sessionRepository,
          filesystemRepository: filesystemRepository,
        ),
        sessionUnseenService: unseenService = buildTestSessionUnseenService(db, plugin),
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
        ),
      ];
      await db.pullRequestDao.upsertPr(
        pullRequest: const PullRequestDto(
          projectId: "/repo",
          branchName: "session-001",
          prNumber: 21,
          url: "https://github.com/org/repo/pull/21",
          title: "Archive PR",
          state: PrState.open,
          mergeableStatus: PrMergeableStatus.unknown,
          reviewDecision: PrReviewDecision.unknown,
          checkStatus: PrCheckStatus.unknown,
          lastCheckedAt: 1,
          createdAt: 1,
        ),
      );

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

      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(0));
      expect(worktreeService.deleteBranchCallCount, equals(0));
      final persisted = await db.sessionDao.getSession(sessionId: "s1");
      expect(persisted?.archivedAt, isNotNull);
      expect(result.id, equals("s1"));
      expect(result.time?.archived, equals(persisted?.archivedAt));
      expect(result.pullRequest?.number, equals(21));
    });

    test("archiving an already-archived session emits no unseen change", () async {
      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        isDedicated: true,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        archivedAt: 12345,
        baseCommit: null,
      );
      plugin.sessionsResult = const [
        PluginSession(
          id: "s1",
          projectID: "/repo",
          directory: "/repo",
          parentID: null,
          title: "Session 1",
          time: PluginSessionTime(created: 10, updated: 20, archived: 12345),
        ),
      ];

      final emitted = <UnseenChange>[];
      final sub = unseenService.unseenChanges.listen(emitted.add);

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
      // Allow any fire-and-forget notify to run.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(emitted, isEmpty);
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
        ),
      ];
      worktreeService.safetyResult = WorktreeSafe();

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

      expect(worktreeService.checkCallCount, equals(1));
      expect(worktreeService.removeCallCount, equals(1));
      expect(worktreeService.lastRemoveWorktreePath, equals("/repo/.worktrees/session-001"));
      final persisted = await db.sessionDao.getSession(sessionId: "s1");
      expect(persisted?.archivedAt, isNotNull);
    });

    test("failed branch deletion preserves the unarchived session for retry", () async {
      await _insertSession(
        db: db,
        sessionId: "s1-failed",
        projectId: "/repo",
        isDedicated: true,
        worktreePath: "/repo/.worktrees/session-001-failed",
        branchName: "session-001-failed",
        baseBranch: null,
        archivedAt: null,
        baseCommit: null,
      );
      worktreeService.deleteBranchResult = false;

      await expectLater(
        () => handler.handle(
          makeRequest("PATCH", "/session/update/archive"),
          body: _archiveRequest(
            sessionId: "s1-failed",
            archived: true,
            deleteWorktree: false,
            deleteBranch: true,
            force: false,
          ),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<SessionCleanupFailedException>()),
      );

      final persisted = await db.sessionDao.getSession(sessionId: "s1-failed");
      expect(persisted?.archivedAt, isNull);
      expect(worktreeService.deleteBranchCallCount, equals(1));
    });

    test("archive with cleanup on dirty worktree throws 409", () async {
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
      worktreeService.safetyResult = WorktreeUnsafe(
        issues: [
          UnstagedChanges(),
          BranchMismatch(expected: "session-001", actual: "main"),
        ],
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

      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(1));
      expect(worktreeService.lastRemoveForce, isTrue);
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
        ),
      ];
      await db.pullRequestDao.upsertPr(
        pullRequest: const PullRequestDto(
          projectId: "/repo",
          branchName: "session-001",
          prNumber: 22,
          url: "https://github.com/org/repo/pull/22",
          title: "Unarchive PR",
          state: PrState.open,
          mergeableStatus: PrMergeableStatus.unknown,
          reviewDecision: PrReviewDecision.unknown,
          checkStatus: PrCheckStatus.unknown,
          lastCheckedAt: 1,
          createdAt: 1,
        ),
      );

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

      expect(worktreeService.restoreCallCount, equals(0));
      final persisted = await db.sessionDao.getSession(sessionId: "s1");
      expect(persisted?.archivedAt, isNull);
      expect(result.time?.archived, isNull);
      expect(result.pullRequest?.number, equals(22));
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
        ),
      ];
      worktreeService.resolveBaseBranchAndCommitResult = (
        baseBranch: "develop",
        baseCommit: "abc123",
        startPoint: "develop",
      );

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

      expect(worktreeService.restoreCallCount, equals(1));
      expect(worktreeService.lastRestoreProjectId, equals("/repo"));
      expect(worktreeService.lastRestoreWorktreePath, equals(deletedWorktreePath));
      expect(worktreeService.lastRestoreBranchName, equals("session-001"));
      expect(worktreeService.lastRestoreBaseBranch, equals("develop"));
      expect(worktreeService.lastRestoreBaseCommit, isNull);
      final persisted = await db.sessionDao.getSession(sessionId: "s1");
      expect(persisted?.archivedAt, isNull);
    });

    test("missing binding returns 404 before plugin or cleanup calls", () async {
      final response = await handler.handleInternal(
        makeRequest(
          "PATCH",
          "/session/update/archive",
          body: jsonEncode(
            _archiveRequest(
              sessionId: "missing",
              archived: true,
              deleteWorktree: true,
              deleteBranch: true,
              force: false,
            ).toJson(),
          ),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, 404);
      expect(plugin.lastArchiveSessionId, isNull);
      expect(worktreeService.checkCallCount, 0);
      expect(worktreeService.removeCallCount, 0);
      expect(worktreeService.deleteBranchCallCount, 0);
    });

    test("stored plugin mismatch returns 503 before plugin I/O or cleanup", () async {
      await _insertSession(
        db: db,
        sessionId: "stale-plugin-session",
        projectId: "/repo",
        isDedicated: true,
        worktreePath: "/repo/.worktrees/stale",
        branchName: "stale",
        baseBranch: null,
        archivedAt: null,
        baseCommit: null,
        pluginId: "stopped-plugin",
      );

      final response = await handler.handleInternal(
        makeRequest(
          "PATCH",
          "/session/update/archive",
          body: jsonEncode(
            _archiveRequest(
              sessionId: "stale-plugin-session",
              archived: true,
              deleteWorktree: true,
              deleteBranch: true,
              force: false,
            ).toJson(),
          ),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, 503);
      expect(plugin.lastArchiveSessionId, isNull);
      expect(worktreeService.checkCallCount, 0);
      expect(worktreeService.removeCallCount, 0);
      expect(worktreeService.deleteBranchCallCount, 0);
      expect((await db.sessionDao.getSession(sessionId: "stale-plugin-session"))?.archivedAt, isNull);
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

      expect(worktreeService.restoreCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(0));
      expect(worktreeService.deleteBranchCallCount, equals(0));
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

      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(0));
      expect(worktreeService.deleteBranchCallCount, equals(0));
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
  String pluginId = "fake",
}) async {
  await db.projectsDao.insertProjectsIfMissing(projectIds: [projectId]); // satisfy v5 FK constraint
  await db.sessionDao.insertSession(
    pluginId: pluginId,
    sessionId: sessionId,
    backendSessionId: sessionId,
    projectId: projectId,
    isDedicated: isDedicated,
    createdAt: 1,
    worktreePath: worktreePath,
    branchName: branchName,
    baseBranch: baseBranch,
    baseCommit: baseCommit,

    lastAgent: null,
    lastAgentModel: null,
  );
  if (archivedAt != null) {
    await db.sessionDao.setArchived(
      sessionId: sessionId,
      archivedAt: archivedAt,
      updatedAt: archivedAt,
      projectionUpdatedAt: archivedAt,
    );
  }
}

class _FakeWorktreeService extends WorktreeService {
  WorktreeSafetyResult safetyResult = WorktreeSafe();
  bool removeResult = true;
  bool deleteBranchResult = true;
  bool branchExistsResult = true;
  bool restoreResult = true;
  ({String baseBranch, String baseCommit, String startPoint})? resolveBaseBranchAndCommitResult;

  int checkCallCount = 0;
  int removeCallCount = 0;
  int deleteBranchCallCount = 0;
  int restoreCallCount = 0;

  String? lastCheckWorktreePath;
  String? lastCheckExpectedBranch;
  String? lastRemoveProjectId;
  String? lastRemoveWorktreePath;
  bool? lastRemoveForce;
  String? lastDeleteBranchProjectId;
  String? lastDeleteBranchName;
  bool? lastDeleteBranchForce;
  String? lastRestoreProjectId;
  String? lastRestoreWorktreePath;
  String? lastRestoreBranchName;
  String? lastRestoreBaseBranch;
  String? lastRestoreBaseCommit;

  _FakeWorktreeService({required AppDatabase database})
    : super(
        worktreeRepository: WorktreeRepository(
          projectsDao: database.projectsDao,
          sessionDao: database.sessionDao,
          gitApi: GitCliApi(
            processRunner: _NoopProcessRunner(),
            gitPathExists: ({required String gitPath}) => true,
          ),
          plugin: _FakeBridgePlugin(),
        ),
      );

  @override
  Future<WorktreeSafetyResult> checkWorktreeSafety({
    required String worktreePath,
    required String expectedBranch,
  }) async {
    checkCallCount++;
    lastCheckWorktreePath = worktreePath;
    lastCheckExpectedBranch = expectedBranch;
    return safetyResult;
  }

  @override
  Future<bool> removeWorktree({
    required String projectId,
    required String worktreePath,
    required bool force,
  }) async {
    removeCallCount++;
    lastRemoveProjectId = projectId;
    lastRemoveWorktreePath = worktreePath;
    lastRemoveForce = force;
    return removeResult;
  }

  @override
  Future<bool> deleteBranch({
    required String projectId,
    required String branchName,
    required bool force,
  }) async {
    deleteBranchCallCount++;
    lastDeleteBranchProjectId = projectId;
    lastDeleteBranchName = branchName;
    lastDeleteBranchForce = force;
    return deleteBranchResult;
  }

  @override
  Future<bool> branchExists({
    required String projectId,
    required String branchName,
  }) async {
    return branchExistsResult;
  }

  @override
  Future<bool> restoreWorktree({
    required String projectId,
    required String worktreePath,
    required String branchName,
    required String baseBranch,
    required String? baseCommit,
  }) async {
    restoreCallCount++;
    lastRestoreProjectId = projectId;
    lastRestoreWorktreePath = worktreePath;
    lastRestoreBranchName = branchName;
    lastRestoreBaseBranch = baseBranch;
    lastRestoreBaseCommit = baseCommit;
    return restoreResult;
  }

  @override
  Future<({String baseBranch, String baseCommit, String startPoint})?> resolveBaseBranchAndCommit({
    required String projectId,
  }) async {
    return resolveBaseBranchAndCommitResult;
  }
}

class _FakeBridgePlugin implements NativeProjectsPluginApi {
  @override
  String get id => "fake";

  @override
  Stream<BridgeSseEvent> get events => const Stream<BridgeSseEvent>.empty();

  @override
  Future<void> deleteWorkspace({
    required String projectId,
    required String worktreePath,
  }) async {}

  @override
  Future<List<PluginProject>> getProjects() async => [];

  @override
  Future<List<PluginSession>> getSessions(String worktree, {int? start, int? limit}) async => [];

  @override
  Future<List<PluginCommand>> getCommands({required String? projectId}) async => [];

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async => throw UnimplementedError();

  @override
  Future<PluginSession> renameSession({required String sessionId, required String title}) async =>
      throw UnimplementedError();

  @override
  Future<PluginProject> renameProject({required String projectId, required String name}) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteSession(String sessionId) async {}

  @override
  Future<void> archiveSession({required String sessionId}) async {}

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) async => [];

  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() async => {};

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId) async => [];

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {}

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
  Future<void> abortSession({required String sessionId}) async {}

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) async => [];

  @override
  Future<List<PluginPendingPermission>> getPendingPermissions({required String sessionId}) async => [];

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({required String sessionId}) async => [];

  @override
  Future<List<PluginPendingQuestion>> getProjectQuestions({required String projectId}) async => [];

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) async {}

  @override
  Future<void> rejectQuestion({required String questionId, required String? sessionId}) async {}

  @override
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) async {}

  @override
  Future<PluginProject> getProject(String projectId) async => throw UnimplementedError();

  @override
  Future<bool> healthCheck() async => true;

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) async =>
      const PluginProvidersResult(providers: []);

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => [];

  @override
  Future<void> dispose() async {}
}

class _NoopProcessRunner implements ProcessRunner {
  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) {
    throw UnimplementedError("_NoopProcessRunner should never execute git commands");
  }
}
