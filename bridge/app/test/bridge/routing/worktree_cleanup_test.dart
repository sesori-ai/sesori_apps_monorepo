import "dart:io";

import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/persistence/tables/session_table.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/worktree_repository.dart";
import "package:sesori_bridge/src/bridge/routing/worktree_cleanup.dart";
import "package:sesori_bridge/src/bridge/services/worktree_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("performWorktreeCleanup", () {
    late AppDatabase db;
    late _FakeWorktreeService worktreeService;
    late _FakeSessionRepository sessionRepository;

    setUp(() {
      db = createTestDatabase();
      worktreeService = _FakeWorktreeService(database: db);
      sessionRepository = _FakeSessionRepository();
    });

    tearDown(() async {
      await db.close();
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
      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(0));
      expect(worktreeService.deleteBranchCallCount, equals(0));
    });

    test("clean worktree removes worktree and returns success", () async {
      worktreeService.safetyResult = WorktreeSafe();

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
        sessionRepository: sessionRepository,
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
      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(1));
      expect(worktreeService.lastRemoveForce, isTrue);
    });

    test("delete worktree and branch runs both operations", () async {
      worktreeService.safetyResult = WorktreeSafe();

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
      expect(worktreeService.checkCallCount, equals(1));
      expect(worktreeService.removeCallCount, equals(1));
      expect(worktreeService.deleteBranchCallCount, equals(1));
      expect(worktreeService.lastDeleteBranchForce, isTrue);
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
      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(0));
      expect(worktreeService.deleteBranchCallCount, equals(0));
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

      // force=true skips both the shared-worktree check and the safety check;
      // cleanup proceeds so the user can resolve the stalemate.
      expect(result, isA<CleanupSuccess>());
      expect(sessionRepository.hasSharingCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(1));
      expect(worktreeService.deleteBranchCallCount, equals(1));
    });

    test("no rejection when no other sessions share worktree", () async {
      sessionRepository.hasSharingResult = false;
      worktreeService.safetyResult = WorktreeSafe();

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
      expect(worktreeService.removeCallCount, equals(1));
    });

    test("no rejection when other session is archived (hasSharingResult=false)", () async {
      // hasSharingResult=false simulates the DAO returning empty (archived sessions excluded)
      sessionRepository.hasSharingResult = false;
      worktreeService.safetyResult = WorktreeSafe();

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
      expect(worktreeService.removeCallCount, equals(1));
      expect(worktreeService.deleteBranchCallCount, equals(1));
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
    return safetyResult;
  }

  @override
  Future<bool> removeWorktree({
    required String projectId,
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

class _FakeBridgePlugin implements BridgePluginApi {
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
  Future<PluginSession> renameSession({required String sessionId, required String title}) async => throw UnimplementedError();

  @override
  Future<PluginProject> renameProject({required String projectId, required String name}) async => throw UnimplementedError();

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
  Future<List<PluginAgent>> getAgents() async => [];

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
  Future<void> rejectQuestion(String questionId) async {}

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
  Future<PluginProvidersResult> getProviders({required String projectId}) async => const PluginProvidersResult(providers: []);

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => [];

  @override
  Future<void> dispose() async {}
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
