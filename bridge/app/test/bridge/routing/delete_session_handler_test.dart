import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/routing/delete_session_handler.dart";
import "package:sesori_bridge/src/bridge/worktree_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("DeleteSessionHandler", () {
    late AppDatabase db;
    late _TrackingFakeBridgePlugin plugin;
    late _FakeWorktreeService worktreeService;
    late DeleteSessionHandler handler;
    late List<String> operationLog;

    setUp(() {
      db = createTestDatabase();
      operationLog = [];
      plugin = _TrackingFakeBridgePlugin(operationLog: operationLog);
      worktreeService = _FakeWorktreeService(database: db, operationLog: operationLog);
      handler = DeleteSessionHandler(
        plugin: plugin,
        worktreeService: worktreeService,
        sessionDao: db.sessionDao,
      );
    });

    tearDown(() async {
      await plugin.close();
      await db.close();
    });

    test("throws 400 on empty session id", () async {
      expect(
        () => handler.handle(
          makeRequest("DELETE", "/session/delete"),
          body: const DeleteSessionRequest(
            sessionId: "",
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

    test("1) deleteWorktree=false deleteBranch=false: plugin+db delete, no git ops", () async {
      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-001",
        branchName: "session-001",
      );

      final response = await handler.handle(
        makeRequest("DELETE", "/session/delete"),
        body: const DeleteSessionRequest(
          sessionId: "s1",
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, isA<SuccessEmptyResponse>());
      expect(plugin.lastDeleteSessionId, equals("s1"));
      expect(await db.sessionDao.getSession(sessionId: "s1"), isNull);
      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(0));
      expect(worktreeService.deleteBranchCallCount, equals(0));
      expect(operationLog, equals(["pluginDelete"]));
    });

    test("2) deleteWorktree=true on clean worktree: safety check then plugin then worktree", () async {
      await _insertSession(
        db: db,
        sessionId: "s2",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-002",
        branchName: "session-002",
      );
      worktreeService.safetyResult = WorktreeSafe();

      final response = await handler.handle(
        makeRequest("DELETE", "/session/delete"),
        body: const DeleteSessionRequest(
          sessionId: "s2",
          deleteWorktree: true,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, isA<SuccessEmptyResponse>());
      expect(worktreeService.checkCallCount, equals(1));
      expect(worktreeService.lastCheckWorktreePath, equals("/repo/.worktrees/session-002"));
      expect(worktreeService.lastCheckExpectedBranch, equals("session-002"));
      expect(worktreeService.removeCallCount, equals(1));
      expect(worktreeService.lastRemoveProjectPath, equals("/repo"));
      expect(worktreeService.lastRemoveWorktreePath, equals("/repo/.worktrees/session-002"));
      expect(worktreeService.lastRemoveForce, isFalse);
      expect(worktreeService.deleteBranchCallCount, equals(0));
      expect(plugin.lastDeleteSessionId, equals("s2"));
      expect(await db.sessionDao.getSession(sessionId: "s2"), isNull);
      expect(operationLog, equals(["checkSafety", "removeWorktree", "pluginDelete"]));
    });

    test("3) deleteBranch=true: deletes branch", () async {
      await _insertSession(
        db: db,
        sessionId: "s3",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-003",
        branchName: "session-003",
      );

      final response = await handler.handle(
        makeRequest("DELETE", "/session/delete"),
        body: const DeleteSessionRequest(
          sessionId: "s3",
          deleteWorktree: false,
          deleteBranch: true,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, isA<SuccessEmptyResponse>());
      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(0));
      expect(worktreeService.deleteBranchCallCount, equals(1));
      expect(worktreeService.lastDeleteBranchProjectPath, equals("/repo"));
      expect(worktreeService.lastDeleteBranchName, equals("session-003"));
      expect(worktreeService.lastDeleteBranchForce, isFalse);
      expect(plugin.lastDeleteSessionId, equals("s3"));
      expect(await db.sessionDao.getSession(sessionId: "s3"), isNull);
      expect(operationLog, equals(["deleteBranch", "pluginDelete"]));
    });

    test("4) deleteWorktree=true + deleteBranch=true: both cleanup operations run", () async {
      await _insertSession(
        db: db,
        sessionId: "s4",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-004",
        branchName: "session-004",
      );
      worktreeService.safetyResult = WorktreeSafe();

      final response = await handler.handle(
        makeRequest("DELETE", "/session/delete"),
        body: const DeleteSessionRequest(
          sessionId: "s4",
          deleteWorktree: true,
          deleteBranch: true,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, isA<SuccessEmptyResponse>());
      expect(worktreeService.checkCallCount, equals(1));
      expect(worktreeService.removeCallCount, equals(1));
      expect(worktreeService.deleteBranchCallCount, equals(1));
      expect(worktreeService.lastDeleteBranchForce, isTrue);
      expect(plugin.lastDeleteSessionId, equals("s4"));
      expect(await db.sessionDao.getSession(sessionId: "s4"), isNull);
      expect(operationLog, equals(["checkSafety", "removeWorktree", "deleteBranch", "pluginDelete"]));
    });

    test("5) deleteWorktree=true on dirty worktree, force=false: returns 409 rejection", () async {
      await _insertSession(
        db: db,
        sessionId: "s5",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-005",
        branchName: "session-005",
      );
      worktreeService.safetyResult = WorktreeUnsafe(
        issues: [
          UnstagedChanges(),
          BranchMismatch(expected: "session-005", actual: "main"),
        ],
      );

      await expectLater(
        () => handler.handle(
          makeRequest("DELETE", "/session/delete"),
          body: const DeleteSessionRequest(
            sessionId: "s5",
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
      expect(worktreeService.removeCallCount, equals(0));
      expect(worktreeService.deleteBranchCallCount, equals(0));
      expect(plugin.lastDeleteSessionId, isNull);
      expect(await db.sessionDao.getSession(sessionId: "s5"), isNotNull);
      expect(operationLog, equals(["checkSafety"]));
    });

    test("6) force=true on dirty worktree: cleanup proceeds", () async {
      await _insertSession(
        db: db,
        sessionId: "s6",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-006",
        branchName: "session-006",
      );
      worktreeService.safetyResult = WorktreeUnsafe(
        issues: [UnstagedChanges()],
      );

      final response = await handler.handle(
        makeRequest("DELETE", "/session/delete"),
        body: const DeleteSessionRequest(
          sessionId: "s6",
          deleteWorktree: true,
          deleteBranch: false,
          force: true,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, isA<SuccessEmptyResponse>());
      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(1));
      expect(worktreeService.lastRemoveForce, isTrue);
      expect(plugin.lastDeleteSessionId, equals("s6"));
      expect(await db.sessionDao.getSession(sessionId: "s6"), isNull);
      expect(operationLog, equals(["removeWorktree", "pluginDelete"]));
    });

    test("7) null worktreePath: skips git ops", () async {
      await _insertSession(
        db: db,
        sessionId: "s7",
        projectId: "/repo",
        worktreePath: null,
        branchName: null,
      );

      final response = await handler.handle(
        makeRequest("DELETE", "/session/delete"),
        body: const DeleteSessionRequest(
          sessionId: "s7",
          deleteWorktree: true,
          deleteBranch: true,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, isA<SuccessEmptyResponse>());
      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(0));
      expect(worktreeService.deleteBranchCallCount, equals(0));
      expect(plugin.lastDeleteSessionId, equals("s7"));
      expect(await db.sessionDao.getSession(sessionId: "s7"), isNull);
      expect(operationLog, equals(["pluginDelete"]));
    });

    test("9) missing DB session: plugin delete only", () async {
      final response = await handler.handle(
        makeRequest("DELETE", "/session/delete"),
        body: const DeleteSessionRequest(
          sessionId: "s9",
          deleteWorktree: true,
          deleteBranch: true,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, isA<SuccessEmptyResponse>());
      expect(plugin.lastDeleteSessionId, equals("s9"));
      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(0));
      expect(worktreeService.deleteBranchCallCount, equals(0));
      expect(await db.sessionDao.getSession(sessionId: "s9"), isNull);
      expect(operationLog, equals(["pluginDelete"]));
    });

    test("10) plugin delete non-404 failure: cleanup already ran and DB row remains", () async {
      await _insertSession(
        db: db,
        sessionId: "s10",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-010",
        branchName: "session-010",
      );
      worktreeService.safetyResult = WorktreeSafe();
      plugin.throwOnDeleteSessionError = PluginApiException("/session/s10", 500);

      await expectLater(
        () => handler.handle(
          makeRequest("DELETE", "/session/delete"),
          body: const DeleteSessionRequest(
            sessionId: "s10",
            deleteWorktree: true,
            deleteBranch: true,
            force: false,
          ),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<PluginApiException>()),
      );

      expect(worktreeService.checkCallCount, equals(1));
      expect(worktreeService.removeCallCount, equals(1));
      expect(worktreeService.deleteBranchCallCount, equals(1));
      expect(await db.sessionDao.getSession(sessionId: "s10"), isNotNull);
      expect(operationLog, equals(["checkSafety", "removeWorktree", "deleteBranch", "pluginDelete"]));
    });
  });
}

Future<void> _insertSession({
  required AppDatabase db,
  required String sessionId,
  required String projectId,
  required String? worktreePath,
  required String? branchName,
}) {
  return db.sessionDao.insertSession(
    sessionId: sessionId,
    projectId: projectId,
    isDedicated: true,
    createdAt: 1,
    worktreePath: worktreePath,
    branchName: branchName,
    baseBranch: null,
    baseCommit: null,
  );
}

class _FakeWorktreeService extends WorktreeService {
  final List<String> operationLog;
  WorktreeSafetyResult safetyResult = WorktreeSafe();
  bool removeResult = true;
  bool deleteBranchResult = true;

  int checkCallCount = 0;
  int removeCallCount = 0;
  int deleteBranchCallCount = 0;

  String? lastCheckWorktreePath;
  String? lastCheckExpectedBranch;
  String? lastRemoveProjectPath;
  String? lastRemoveWorktreePath;
  bool? lastRemoveForce;
  String? lastDeleteBranchProjectPath;
  String? lastDeleteBranchName;
  bool? lastDeleteBranchForce;

  _FakeWorktreeService({required AppDatabase database, required this.operationLog})
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
    operationLog.add("checkSafety");
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
    operationLog.add("removeWorktree");
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
    operationLog.add("deleteBranch");
    lastDeleteBranchProjectPath = projectPath;
    lastDeleteBranchName = branchName;
    lastDeleteBranchForce = force;
    return deleteBranchResult;
  }
}

class _TrackingFakeBridgePlugin extends FakeBridgePlugin {
  final List<String> operationLog;

  _TrackingFakeBridgePlugin({required this.operationLog});

  @override
  Future<void> deleteSession(String sessionId) async {
    operationLog.add("pluginDelete");
    await super.deleteSession(sessionId);
  }
}
