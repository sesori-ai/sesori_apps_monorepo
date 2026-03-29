import "dart:convert";

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

    test("1) deleteWorktree=false deleteBranch=false: plugin+db delete, no git ops", () async {
      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-001",
        branchName: "session-001",
      );

      final response = await handler.handle(
        makeRequest(
          "DELETE",
          "/session/s1",
          body: jsonEncode(
            const DeleteSessionRequest(
              deleteWorktree: false,
              deleteBranch: false,
              force: false,
            ).toJson(),
          ),
        ),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(200));
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
        makeRequest(
          "DELETE",
          "/session/s2",
          body: jsonEncode(
            const DeleteSessionRequest(
              deleteWorktree: true,
              deleteBranch: false,
              force: false,
            ).toJson(),
          ),
        ),
        pathParams: {"id": "s2"},
        queryParams: {},
      );

      expect(response.status, equals(200));
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
      expect(operationLog, equals(["checkSafety", "pluginDelete", "removeWorktree"]));
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
        makeRequest(
          "DELETE",
          "/session/s3",
          body: jsonEncode(
            const DeleteSessionRequest(
              deleteWorktree: false,
              deleteBranch: true,
              force: false,
            ).toJson(),
          ),
        ),
        pathParams: {"id": "s3"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(0));
      expect(worktreeService.deleteBranchCallCount, equals(1));
      expect(worktreeService.lastDeleteBranchProjectPath, equals("/repo"));
      expect(worktreeService.lastDeleteBranchName, equals("session-003"));
      expect(worktreeService.lastDeleteBranchForce, isFalse);
      expect(plugin.lastDeleteSessionId, equals("s3"));
      expect(await db.sessionDao.getSession(sessionId: "s3"), isNull);
      expect(operationLog, equals(["pluginDelete", "deleteBranch"]));
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
        makeRequest(
          "DELETE",
          "/session/s4",
          body: jsonEncode(
            const DeleteSessionRequest(
              deleteWorktree: true,
              deleteBranch: true,
              force: false,
            ).toJson(),
          ),
        ),
        pathParams: {"id": "s4"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(worktreeService.checkCallCount, equals(1));
      expect(worktreeService.removeCallCount, equals(1));
      expect(worktreeService.deleteBranchCallCount, equals(1));
      expect(worktreeService.lastDeleteBranchForce, isTrue);
      expect(plugin.lastDeleteSessionId, equals("s4"));
      expect(await db.sessionDao.getSession(sessionId: "s4"), isNull);
      expect(operationLog, equals(["checkSafety", "pluginDelete", "removeWorktree", "deleteBranch"]));
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

      final response = await handler.handle(
        makeRequest(
          "DELETE",
          "/session/s5",
          body: jsonEncode(
            const DeleteSessionRequest(
              deleteWorktree: true,
              deleteBranch: false,
              force: false,
            ).toJson(),
          ),
        ),
        pathParams: {"id": "s5"},
        queryParams: {},
      );

      expect(response.status, equals(409));
      final rejection = SessionCleanupRejection.fromJson(
        switch (jsonDecode(response.body!)) {
          final Map<String, dynamic> map => map,
          _ => throw StateError("expected JSON object"),
        },
      );
      expect(rejection.issues, hasLength(2));
      expect(
        rejection.issues,
        equals(
          const [
            CleanupIssue.unstagedChanges(),
            CleanupIssue.branchMismatch(expected: "session-005", actual: "main"),
          ],
        ),
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
        makeRequest(
          "DELETE",
          "/session/s6",
          body: jsonEncode(
            const DeleteSessionRequest(
              deleteWorktree: true,
              deleteBranch: false,
              force: true,
            ).toJson(),
          ),
        ),
        pathParams: {"id": "s6"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(1));
      expect(worktreeService.lastRemoveForce, isTrue);
      expect(plugin.lastDeleteSessionId, equals("s6"));
      expect(await db.sessionDao.getSession(sessionId: "s6"), isNull);
      expect(operationLog, equals(["pluginDelete", "removeWorktree"]));
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
        makeRequest(
          "DELETE",
          "/session/s7",
          body: jsonEncode(
            const DeleteSessionRequest(
              deleteWorktree: true,
              deleteBranch: true,
              force: false,
            ).toJson(),
          ),
        ),
        pathParams: {"id": "s7"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(0));
      expect(worktreeService.deleteBranchCallCount, equals(0));
      expect(plugin.lastDeleteSessionId, equals("s7"));
      expect(await db.sessionDao.getSession(sessionId: "s7"), isNull);
      expect(operationLog, equals(["pluginDelete"]));
    });

    test("8) shared worktree: skips worktree removal", () async {
      await _insertSession(
        db: db,
        sessionId: "s8-primary",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-shared",
        branchName: "session-shared",
      );
      await _insertSession(
        db: db,
        sessionId: "s8-secondary",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-shared",
        branchName: "session-shared",
      );

      final response = await handler.handle(
        makeRequest(
          "DELETE",
          "/session/s8-primary",
          body: jsonEncode(
            const DeleteSessionRequest(
              deleteWorktree: true,
              deleteBranch: false,
              force: false,
            ).toJson(),
          ),
        ),
        pathParams: {"id": "s8-primary"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(0));
      expect(worktreeService.deleteBranchCallCount, equals(0));
      expect(await db.sessionDao.getSession(sessionId: "s8-primary"), isNull);
      expect(await db.sessionDao.getSession(sessionId: "s8-secondary"), isNotNull);
      expect(operationLog, equals(["pluginDelete"]));
    });

    test("9) missing DB session: plugin delete only", () async {
      final response = await handler.handle(
        makeRequest(
          "DELETE",
          "/session/s9",
          body: jsonEncode(
            const DeleteSessionRequest(
              deleteWorktree: true,
              deleteBranch: true,
              force: false,
            ).toJson(),
          ),
        ),
        pathParams: {"id": "s9"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(plugin.lastDeleteSessionId, equals("s9"));
      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(0));
      expect(worktreeService.deleteBranchCallCount, equals(0));
      expect(await db.sessionDao.getSession(sessionId: "s9"), isNull);
      expect(operationLog, equals(["pluginDelete"]));
    });

    test("10) plugin delete non-404 failure: no git cleanup and DB row remains", () async {
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
          makeRequest(
            "DELETE",
            "/session/s10",
            body: jsonEncode(
              const DeleteSessionRequest(
                deleteWorktree: true,
                deleteBranch: true,
                force: false,
              ).toJson(),
            ),
          ),
          pathParams: {"id": "s10"},
          queryParams: {},
        ),
        throwsA(isA<PluginApiException>()),
      );

      expect(worktreeService.checkCallCount, equals(1));
      expect(worktreeService.removeCallCount, equals(0));
      expect(worktreeService.deleteBranchCallCount, equals(0));
      expect(await db.sessionDao.getSession(sessionId: "s10"), isNotNull);
      expect(operationLog, equals(["checkSafety", "pluginDelete"]));
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
