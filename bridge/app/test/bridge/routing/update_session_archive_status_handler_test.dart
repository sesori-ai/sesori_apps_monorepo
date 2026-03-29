import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/routing/update_session_archive_status_handler.dart";
import "package:sesori_bridge/src/bridge/worktree_service.dart";
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
    late UpdateSessionArchiveStatusHandler handler;

    setUp(() {
      db = createTestDatabase();
      plugin = FakeBridgePlugin();
      worktreeService = _FakeWorktreeService(database: db);
      handler = UpdateSessionArchiveStatusHandler(
        plugin: plugin,
        worktreeService: worktreeService,
        sessionDao: db.sessionDao,
      );
    });

    tearDown(() async {
      await plugin.close();
      await db.close();
    });

    test("canHandle PATCH /session/:id", () {
      expect(handler.canHandle(makeRequest("PATCH", "/session/s1")), isTrue);
    });

    test("does not handle GET /session/:id", () {
      expect(handler.canHandle(makeRequest("GET", "/session/s1")), isFalse);
    });

    test("1) archive without cleanup: sets archivedAt and does not run git cleanup", () async {
      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        isDedicated: true,
        worktreePath: "/repo/.worktrees/session-001",
        branchName: "session-001",
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

      final response = await handler.handle(
        makeRequest(
          "PATCH",
          "/session/s1",
          body: _archiveBody(
            archived: true,
            deleteWorktree: false,
            deleteBranch: false,
            force: false,
          ),
        ),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(0));
      expect(worktreeService.deleteBranchCallCount, equals(0));
      final persisted = await db.sessionDao.getSession(sessionId: "s1");
      expect(persisted?.archivedAt, isNotNull);

      final session = Session.fromJson(
        switch (jsonDecode(response.body!)) {
          final Map<String, dynamic> map => map,
          _ => throw StateError("expected JSON object"),
        },
      );
      expect(session.id, equals("s1"));
      expect(session.time?.archived, equals(persisted?.archivedAt));
    });

    test("2) archive with cleanup on clean worktree: removes worktree and sets archivedAt", () async {
      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        isDedicated: true,
        worktreePath: "/repo/.worktrees/session-001",
        branchName: "session-001",
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
      worktreeService.safetyResult = WorktreeSafe();

      final response = await handler.handle(
        makeRequest(
          "PATCH",
          "/session/s1",
          body: _archiveBody(
            archived: true,
            deleteWorktree: true,
            deleteBranch: false,
            force: false,
          ),
        ),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(worktreeService.checkCallCount, equals(1));
      expect(worktreeService.removeCallCount, equals(1));
      expect(worktreeService.lastRemoveWorktreePath, equals("/repo/.worktrees/session-001"));
      final persisted = await db.sessionDao.getSession(sessionId: "s1");
      expect(persisted?.archivedAt, isNotNull);
    });

    test("3) archive with cleanup on dirty worktree: returns 409 rejection", () async {
      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        isDedicated: true,
        worktreePath: "/repo/.worktrees/session-001",
        branchName: "session-001",
      );
      worktreeService.safetyResult = WorktreeUnsafe(
        issues: [
          UnstagedChanges(),
          BranchMismatch(expected: "session-001", actual: "main"),
        ],
      );

      final response = await handler.handle(
        makeRequest(
          "PATCH",
          "/session/s1",
          body: _archiveBody(
            archived: true,
            deleteWorktree: true,
            deleteBranch: false,
            force: false,
          ),
        ),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(409));
      final persisted = await db.sessionDao.getSession(sessionId: "s1");
      expect(persisted?.archivedAt, isNull);
      final rejection = SessionCleanupRejection.fromJson(
        switch (jsonDecode(response.body!)) {
          final Map<String, dynamic> map => map,
          _ => throw StateError("expected JSON object"),
        },
      );
      expect(rejection.issues, hasLength(2));
    });

    test("4) archive with force: proceeds without safety check", () async {
      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        isDedicated: true,
        worktreePath: "/repo/.worktrees/session-001",
        branchName: "session-001",
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

      final response = await handler.handle(
        makeRequest(
          "PATCH",
          "/session/s1",
          body: _archiveBody(
            archived: true,
            deleteWorktree: true,
            deleteBranch: false,
            force: true,
          ),
        ),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(1));
      expect(worktreeService.lastRemoveForce, isTrue);
    });

    test("5) unarchive with existing worktree: clears archivedAt and does not restore", () async {
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
        archivedAt: 123,
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

      final response = await handler.handle(
        makeRequest(
          "PATCH",
          "/session/s1",
          body: _archiveBody(
            archived: false,
            deleteWorktree: false,
            deleteBranch: false,
            force: false,
          ),
        ),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(worktreeService.restoreCallCount, equals(0));
      final persisted = await db.sessionDao.getSession(sessionId: "s1");
      expect(persisted?.archivedAt, isNull);
      final session = Session.fromJson(
        switch (jsonDecode(response.body!)) {
          final Map<String, dynamic> map => map,
          _ => throw StateError("expected JSON object"),
        },
      );
      expect(session.time?.archived, isNull);
    });

    test("6) unarchive with deleted worktree: clears archivedAt and restores worktree", () async {
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

      final response = await handler.handle(
        makeRequest(
          "PATCH",
          "/session/s1",
          body: _archiveBody(
            archived: false,
            deleteWorktree: false,
            deleteBranch: false,
            force: false,
          ),
        ),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(worktreeService.restoreCallCount, equals(1));
      expect(worktreeService.lastRestoreProjectPath, equals("/repo"));
      expect(worktreeService.lastRestoreWorktreePath, equals(deletedWorktreePath));
      expect(worktreeService.lastRestoreBranchName, equals("session-001"));
      expect(worktreeService.lastRestoreBaseBranch, equals("main"));
      expect(worktreeService.lastRestoreBaseCommit, isNull);
      final persisted = await db.sessionDao.getSession(sessionId: "s1");
      expect(persisted?.archivedAt, isNull);
    });

    test("10) archive pre-migration session: auto-inserts row and archives", () async {
      plugin.projectsResult = const [
        PluginProject(id: "/repo"),
      ];
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

      final response = await handler.handle(
        makeRequest(
          "PATCH",
          "/session/s-pre-migration",
          body: _archiveBody(
            archived: true,
            deleteWorktree: false,
            deleteBranch: false,
            force: false,
          ),
        ),
        pathParams: {"id": "s-pre-migration"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      final persisted = await db.sessionDao.getSession(sessionId: "s-pre-migration");
      expect(persisted, isNotNull);
      expect(persisted?.projectId, equals("/repo"));
      expect(persisted?.isDedicated, isTrue);
      expect(persisted?.worktreePath, isNull);
      expect(persisted?.branchName, isNull);
      expect(persisted?.baseBranch, isNull);
      expect(persisted?.baseCommit, isNull);
      expect(persisted?.archivedAt, isNotNull);
    });

    test("7) unarchive simple session: clears archivedAt and no worktree operations", () async {
      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        isDedicated: false,
        worktreePath: null,
        branchName: null,
        archivedAt: 123,
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

      final response = await handler.handle(
        makeRequest(
          "PATCH",
          "/session/s1",
          body: _archiveBody(
            archived: false,
            deleteWorktree: false,
            deleteBranch: false,
            force: false,
          ),
        ),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(worktreeService.restoreCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(0));
      expect(worktreeService.deleteBranchCallCount, equals(0));
      final persisted = await db.sessionDao.getSession(sessionId: "s1");
      expect(persisted?.archivedAt, isNull);
    });

    test("8) archive simple session: sets archivedAt and skips cleanup", () async {
      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        isDedicated: false,
        worktreePath: null,
        branchName: null,
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

      final response = await handler.handle(
        makeRequest(
          "PATCH",
          "/session/s1",
          body: _archiveBody(
            archived: true,
            deleteWorktree: true,
            deleteBranch: true,
            force: false,
          ),
        ),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(0));
      expect(worktreeService.deleteBranchCallCount, equals(0));
      final persisted = await db.sessionDao.getSession(sessionId: "s1");
      expect(persisted?.archivedAt, isNotNull);
    });

    test("9) session ID preserved on unarchive response", () async {
      await _insertSession(
        db: db,
        sessionId: "s-preserve",
        projectId: "/repo",
        isDedicated: false,
        worktreePath: null,
        branchName: null,
        archivedAt: 123,
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

      final response = await handler.handle(
        makeRequest(
          "PATCH",
          "/session/s-preserve",
          body: _archiveBody(
            archived: false,
            deleteWorktree: false,
            deleteBranch: false,
            force: false,
          ),
        ),
        pathParams: {"id": "s-preserve"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      final session = Session.fromJson(
        switch (jsonDecode(response.body!)) {
          final Map<String, dynamic> map => map,
          _ => throw StateError("expected JSON object"),
        },
      );
      expect(session.id, equals("s-preserve"));
      expect(session.time?.archived, isNull);
    });

    test("returns 400 when body has no archived key", () async {
      final response = await handler.handle(
        makeRequest("PATCH", "/session/s1", body: "{}"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("invalid JSON body"));
    });

    test("returns 400 when path param id is missing", () async {
      final response = await handler.handle(
        makeRequest(
          "PATCH",
          "/session/s1",
          body: _archiveBody(
            archived: true,
            deleteWorktree: false,
            deleteBranch: false,
            force: false,
          ),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("missing session id"));
    });

    test("returns 400 on malformed body", () async {
      final response = await handler.handle(
        makeRequest("PATCH", "/session/s1", body: "not-json"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(400));
    });
  });
}

String _archiveBody({
  required bool archived,
  required bool deleteWorktree,
  required bool deleteBranch,
  required bool force,
}) {
  return jsonEncode(
    UpdateSessionArchiveRequest(
      archived: archived,
      deleteWorktree: deleteWorktree,
      deleteBranch: deleteBranch,
      force: force,
    ).toJson(),
  );
}

Future<void> _insertSession({
  required AppDatabase db,
  required String sessionId,
  required String projectId,
  required bool isDedicated,
  required String? worktreePath,
  required String? branchName,
  String? baseBranch,
  int? archivedAt,
  String? baseCommit,
}) async {
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
  WorktreeSafetyResult safetyResult = WorktreeSafe();
  bool removeResult = true;
  bool deleteBranchResult = true;
  bool restoreResult = true;

  int checkCallCount = 0;
  int removeCallCount = 0;
  int deleteBranchCallCount = 0;
  int restoreCallCount = 0;

  String? lastCheckWorktreePath;
  String? lastCheckExpectedBranch;
  String? lastRemoveProjectPath;
  String? lastRemoveWorktreePath;
  bool? lastRemoveForce;
  String? lastDeleteBranchProjectPath;
  String? lastDeleteBranchName;
  bool? lastDeleteBranchForce;
  String? lastRestoreProjectPath;
  String? lastRestoreWorktreePath;
  String? lastRestoreBranchName;
  String? lastRestoreBaseBranch;
  String? lastRestoreBaseCommit;

  _FakeWorktreeService({required AppDatabase database})
    : super(
        projectsDao: database.projectsDao,
        sessionDao: database.sessionDao,
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
    required String projectPath,
    required String worktreePath,
    required bool force,
  }) async {
    removeCallCount++;
    lastRemoveProjectPath = projectPath;
    lastRemoveWorktreePath = worktreePath;
    lastRemoveForce = force;
    return removeResult;
  }

  @override
  Future<bool> deleteBranch({
    required String projectPath,
    required String branchName,
    required bool force,
  }) async {
    deleteBranchCallCount++;
    lastDeleteBranchProjectPath = projectPath;
    lastDeleteBranchName = branchName;
    lastDeleteBranchForce = force;
    return deleteBranchResult;
  }

  @override
  Future<bool> restoreWorktree({
    required String projectPath,
    required String worktreePath,
    required String branchName,
    required String baseBranch,
    required String? baseCommit,
  }) async {
    restoreCallCount++;
    lastRestoreProjectPath = projectPath;
    lastRestoreWorktreePath = worktreePath;
    lastRestoreBranchName = branchName;
    lastRestoreBaseBranch = baseBranch;
    lastRestoreBaseCommit = baseCommit;
    return restoreResult;
  }
}
