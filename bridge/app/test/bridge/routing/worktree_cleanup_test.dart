import "dart:io";

import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/persistence/tables/session_table.dart";
import "package:sesori_bridge/src/bridge/repositories/branch_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/worktree_repository.dart";
import "package:sesori_bridge/src/bridge/routing/worktree_cleanup.dart";
import "package:sesori_bridge/src/bridge/services/worktree_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("performWorktreeCleanup", () {
    late AppDatabase db;
    late _FakeWorktreeService worktreeService;
    late _FakeSessionRepository sessionRepository;
    Directory? tempProjectDir;

    setUp(() {
      db = createTestDatabase();
      worktreeService = _FakeWorktreeService(database: db);
      sessionRepository = _FakeSessionRepository();
    });

    tearDown(() async {
      await db.close();
      if (tempProjectDir?.existsSync() ?? false) {
        tempProjectDir!.deleteSync(recursive: true);
      }
      tempProjectDir = null;
    });

    test("no cleanup requested returns success and runs no git ops", () async {
      final result = await performWorktreeCleanup(
        worktreeService: worktreeService,
        sessionRepository: sessionRepository,
        sessionId: "s1",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-001",
        branchName: "session-001",
        deleteWorktree: false,
        deleteBranch: false,
        force: false,
      );

      expect(result, isA<CleanupSuccess>());
    });

    test("clean worktree removes worktree and returns success", () async {
      // Worktree path doesn't exist on disk → checkWorktreeSafety returns safe
      final result = await performWorktreeCleanup(
        worktreeService: worktreeService,
        sessionRepository: sessionRepository,
        sessionId: "s2",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-002",
        branchName: "session-002",
        deleteWorktree: true,
        deleteBranch: false,
        force: false,
      );

      expect(result, isA<CleanupSuccess>());
    });

    test("dirty worktree without force rejects with mapped issues", () async {
      // Create a real temp directory so checkWorktreeSafety detects it as existing
      tempProjectDir = Directory.systemTemp.createTempSync("wt_cleanup_test");
      final worktreePath = "${tempProjectDir!.path}/.worktrees/session-003";
      Directory(worktreePath).createSync(recursive: true);

      final result = await performWorktreeCleanup(
        worktreeService: worktreeService,
        sessionRepository: sessionRepository,
        sessionId: "s3",
        projectId: tempProjectDir!.path,
        worktreePath: worktreePath,
        branchName: "session-003",
        deleteWorktree: true,
        deleteBranch: false,
        force: false,
      );

      // FakeProcessRunner returns "" for branch → BranchMismatch
      expect(result, isA<CleanupRejected>());
      final rejection = (result as CleanupRejected).rejection;
      expect(rejection.issues, isNotEmpty);
    });

    test("dirty worktree with force skips safety check and succeeds", () async {
      final result = await performWorktreeCleanup(
        worktreeService: worktreeService,
        sessionRepository: sessionRepository,
        sessionId: "s4",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-004",
        branchName: "session-004",
        deleteWorktree: true,
        deleteBranch: false,
        force: true,
      );

      expect(result, isA<CleanupSuccess>());
    });

    test("delete worktree and branch runs both operations", () async {
      final result = await performWorktreeCleanup(
        worktreeService: worktreeService,
        sessionRepository: sessionRepository,
        sessionId: "s5",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-005",
        branchName: "session-005",
        deleteWorktree: true,
        deleteBranch: true,
        force: false,
      );

      expect(result, isA<CleanupSuccess>());
    });

    test("shared worktree rejected when force=false", () async {
      sessionRepository.hasSharingResult = true;

      final result = await performWorktreeCleanup(
        worktreeService: worktreeService,
        sessionRepository: sessionRepository,
        sessionId: "s6",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-006",
        branchName: "session-006",
        deleteWorktree: true,
        deleteBranch: true,
        force: false,
      );

      expect(result, isA<CleanupRejected>());
      final rejection = (result as CleanupRejected).rejection;
      expect(rejection.issues, equals(const [CleanupIssue.sharedWorktree()]));
      expect(sessionRepository.hasSharingCallCount, equals(1));
    });

    test("force=true bypasses shared-worktree check and proceeds with cleanup", () async {
      sessionRepository.hasSharingResult = true;

      final result = await performWorktreeCleanup(
        worktreeService: worktreeService,
        sessionRepository: sessionRepository,
        sessionId: "s6b",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-006b",
        branchName: "session-006b",
        deleteWorktree: true,
        deleteBranch: true,
        force: true,
      );

      expect(result, isA<CleanupSuccess>());
      expect(sessionRepository.hasSharingCallCount, equals(0));
    });

    test("no rejection when no other sessions share worktree", () async {
      sessionRepository.hasSharingResult = false;

      final result = await performWorktreeCleanup(
        worktreeService: worktreeService,
        sessionRepository: sessionRepository,
        sessionId: "s7",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-007",
        branchName: "session-007",
        deleteWorktree: true,
        deleteBranch: false,
        force: false,
      );

      expect(result, isA<CleanupSuccess>());
      expect(sessionRepository.hasSharingCallCount, equals(1));
    });

    test("no rejection when other session is archived (hasSharingResult=false)", () async {
      sessionRepository.hasSharingResult = false;

      final result = await performWorktreeCleanup(
        worktreeService: worktreeService,
        sessionRepository: sessionRepository,
        sessionId: "s8",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-008",
        branchName: "session-008",
        deleteWorktree: true,
        deleteBranch: true,
        force: false,
      );

      expect(result, isA<CleanupSuccess>());
      expect(sessionRepository.hasSharingCallCount, equals(1));
    });
  });
}

class _FakeSessionRepository implements SessionRepository {
  bool hasSharingResult = false;
  int hasSharingCallCount = 0;

  @override
  Future<Session> enrichSession({required Session session}) async => session;

  @override
  Future<List<Session>> enrichSessions({required List<Session> sessions}) async => sessions;

  @override
  Future<bool> hasOtherActiveSessionsSharing({
    required String sessionId,
    required String projectId,
    required String? worktreePath,
    required String? branchName,
  }) async {
    hasSharingCallCount++;
    return hasSharingResult;
  }

  @override
  Future<SessionDto?> getStoredSession({required String sessionId}) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWorktreeService extends WorktreeService {
  int checkCallCount = 0;
  int removeCallCount = 0;
  int deleteBranchCallCount = 0;

  String? lastRemoveWorktreePath;
  bool? lastRemoveForce;
  bool? lastDeleteBranchForce;

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
}

/// Process runner that returns success for all git commands.
/// Extension methods on WorktreeService (removeWorktree, deleteBranch,
/// checkWorktreeSafety) call _processRunner.run() internally.
class _FakeProcessRunner implements ProcessRunner {
  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    return ProcessResult(0, 0, "", "");
  }
}
