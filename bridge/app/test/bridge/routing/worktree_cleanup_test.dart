import "dart:io";

import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/routing/worktree_cleanup.dart";
import "package:sesori_bridge/src/bridge/worktree_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("performWorktreeCleanup", () {
    late AppDatabase db;
    late _FakeWorktreeService worktreeService;

    setUp(() {
      db = createTestDatabase();
      worktreeService = _FakeWorktreeService(database: db);
    });

    tearDown(() async {
      await db.close();
    });

    test("no cleanup requested returns success and runs no git ops", () async {
      final result = await performWorktreeCleanup(
        worktreeService: worktreeService,
        sessionId: "s1",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-001",
        branchName: "session-001",
        deleteWorktree: false,
        deleteBranch: false,
        force: false,
      );

      expect(result, isA<CleanupSuccess>());
      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(0));
      expect(worktreeService.deleteBranchCallCount, equals(0));
    });

    test("clean worktree removes worktree and returns success", () async {
      worktreeService.safetyResult = WorktreeSafe();

      final result = await performWorktreeCleanup(
        worktreeService: worktreeService,
        sessionId: "s2",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-002",
        branchName: "session-002",
        deleteWorktree: true,
        deleteBranch: false,
        force: false,
      );

      expect(result, isA<CleanupSuccess>());
      expect(worktreeService.checkCallCount, equals(1));
      expect(worktreeService.removeCallCount, equals(1));
      expect(worktreeService.lastRemoveWorktreePath, equals("/repo/.worktrees/session-002"));
      expect(worktreeService.deleteBranchCallCount, equals(0));
    });

    test("dirty worktree without force rejects with mapped issues", () async {
      worktreeService.safetyResult = WorktreeUnsafe(
        issues: [
          UnstagedChanges(),
          BranchMismatch(expected: "session-003", actual: "main"),
        ],
      );

      final result = await performWorktreeCleanup(
        worktreeService: worktreeService,
        sessionId: "s3",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-003",
        branchName: "session-003",
        deleteWorktree: true,
        deleteBranch: false,
        force: false,
      );

      expect(result, isA<CleanupRejected>());
      final rejection = (result as CleanupRejected).rejection;
      expect(
        rejection.issues,
        equals(
          const [
            CleanupIssue.unstagedChanges(),
            CleanupIssue.branchMismatch(expected: "session-003", actual: "main"),
          ],
        ),
      );
      expect(worktreeService.removeCallCount, equals(0));
      expect(worktreeService.deleteBranchCallCount, equals(0));
    });

    test("dirty worktree with force skips safety check and succeeds", () async {
      worktreeService.safetyResult = WorktreeUnsafe(
        issues: [UnstagedChanges()],
      );

      final result = await performWorktreeCleanup(
        worktreeService: worktreeService,
        sessionId: "s4",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-004",
        branchName: "session-004",
        deleteWorktree: true,
        deleteBranch: false,
        force: true,
      );

      expect(result, isA<CleanupSuccess>());
      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(1));
      expect(worktreeService.lastRemoveForce, isTrue);
    });

    test("delete worktree and branch runs both operations", () async {
      worktreeService.safetyResult = WorktreeSafe();

      final result = await performWorktreeCleanup(
        worktreeService: worktreeService,
        sessionId: "s5",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-005",
        branchName: "session-005",
        deleteWorktree: true,
        deleteBranch: true,
        force: false,
      );

      expect(result, isA<CleanupSuccess>());
      expect(worktreeService.checkCallCount, equals(1));
      expect(worktreeService.removeCallCount, equals(1));
      expect(worktreeService.deleteBranchCallCount, equals(1));
      expect(worktreeService.lastDeleteBranchForce, isTrue);
    });
  });
}

class _FakeWorktreeService extends WorktreeService {
  WorktreeSafetyResult safetyResult = WorktreeSafe();
  bool removeResult = true;
  bool deleteBranchResult = true;

  int checkCallCount = 0;
  int removeCallCount = 0;
  int deleteBranchCallCount = 0;

  String? lastRemoveWorktreePath;
  bool? lastRemoveForce;
  bool? lastDeleteBranchForce;

  _FakeWorktreeService({required AppDatabase database})
    : super(
        projectsDao: database.projectsDao,
        sessionDao: database.sessionDao,
        processRunner: _NoopProcessRunner(),
        gitPathExists: ({required String gitPath}) => true,
      );

  @override
  Future<WorktreeSafetyResult> checkWorktreeSafety({
    required String worktreePath,
    required String expectedBranch,
  }) async {
    checkCallCount++;
    return safetyResult;
  }

  @override
  Future<bool> removeWorktree({
    required String projectPath,
    required String worktreePath,
    required bool force,
  }) async {
    removeCallCount++;
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
    lastDeleteBranchForce = force;
    return deleteBranchResult;
  }
}

class _NoopProcessRunner implements ProcessRunner {
  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) {
    throw UnimplementedError("_NoopProcessRunner should never execute git commands");
  }
}
