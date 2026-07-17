import "dart:io";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/api/filesystem_api.dart";
import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/filesystem_permission_validator.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/repositories/filesystem_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/models/session_operation.dart";
import "package:sesori_bridge/src/bridge/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/services/session_lifecycle_service.dart";
import "package:sesori_bridge/src/bridge/services/worktree_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  group("SessionLifecycleService cleanup", () {
    late AppDatabase db;
    late _FakeWorktreeService worktreeService;
    late _FakeSessionRepository sessionRepository;
    late SessionLifecycleService service;

    setUp(() {
      db = createTestDatabase();
      worktreeService = _FakeWorktreeService(database: db);
      sessionRepository = _FakeSessionRepository();
      service = SessionLifecycleService(
        worktreeService: worktreeService,
        sessionRepository: sessionRepository,
        filesystemRepository: FilesystemRepository(
          filesystemApi: const FilesystemApi(),
          permissionValidator: const FilesystemPermissionValidator(),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test("no cleanup requested returns success and runs no git ops", () async {
      final result = await _cleanup(
        service: service,
        sessionRepository: sessionRepository,
        sessionId: "s1",
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

    test("missing root binding is an explicit not-found failure", () async {
      await expectLater(
        service.cleanup(
          sessionId: "missing",
          deleteWorktree: true,
          deleteBranch: true,
          force: false,
        ),
        throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "isNotFound", isTrue)),
      );

      expect(worktreeService.checkCallCount, isZero);
      expect(worktreeService.removeCallCount, isZero);
      expect(worktreeService.deleteBranchCallCount, isZero);
    });

    test("plugin mismatch is rejected before archive cleanup or plugin I/O", () async {
      sessionRepository.storedSession = const StoredSession(
        id: "s-mismatch",
        backendSessionId: "backend-mismatch",
        pluginId: "other",
        projectId: "/repo",
        parentSessionId: null,
        directory: "/repo/.worktrees/mismatch",
        worktreePath: "/repo/.worktrees/mismatch",
        branchName: "mismatch",
        isDedicated: true,
        archivedAt: null,
        baseBranch: "main",
        baseCommit: "abc123",
      );

      await expectLater(
        service.updateArchiveStatus(
          sessionId: "s-mismatch",
          archived: true,
          deleteWorktree: true,
          deleteBranch: true,
          force: true,
        ),
        throwsA(isA<PluginOperationException>().having((error) => error.statusCode, "statusCode", 503)),
      );

      expect(worktreeService.checkCallCount, isZero);
      expect(worktreeService.removeCallCount, isZero);
      expect(worktreeService.deleteBranchCallCount, isZero);
    });

    test("clean worktree removes worktree and returns success", () async {
      worktreeService.safetyResult = WorktreeSafe();

      final result = await _cleanup(
        service: service,
        sessionRepository: sessionRepository,
        sessionId: "s2",
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

    test("failed worktree removal throws instead of reporting success", () async {
      worktreeService.safetyResult = WorktreeSafe();
      worktreeService.removeResult = false;
      final worktree = Directory.systemTemp.createTempSync("cleanup_failure_");
      addTearDown(() {
        if (worktree.existsSync()) worktree.deleteSync(recursive: true);
      });

      await expectLater(
        () => _cleanup(
          service: service,
          sessionRepository: sessionRepository,
          sessionId: "s2-failed",
          worktreePath: worktree.path,
          branchName: "session-002-failed",
          deleteWorktree: true,
          deleteBranch: false,
          force: false,
        ),
        throwsA(
          isA<SessionCleanupFailedException>().having(
            (error) => error.operation,
            "operation",
            SessionCleanupOperation.removeWorktree,
          ),
        ),
      );
    });

    test("identical retry continues branch cleanup after worktree was removed", () async {
      worktreeService.safetyResult = WorktreeSafe();
      worktreeService.deleteBranchResult = false;
      final worktree = Directory.systemTemp.createTempSync("cleanup_retry_");
      addTearDown(() {
        if (worktree.existsSync()) worktree.deleteSync(recursive: true);
      });

      await expectLater(
        () => _cleanup(
          service: service,
          sessionRepository: sessionRepository,
          sessionId: "s2-retry",
          worktreePath: worktree.path,
          branchName: "session-002-retry",
          deleteWorktree: true,
          deleteBranch: true,
          force: true,
        ),
        throwsA(isA<SessionCleanupFailedException>()),
      );
      worktree.deleteSync(recursive: true);
      worktreeService.removeResult = false;
      worktreeService.deleteBranchResult = true;

      final retryResult = await _cleanup(
        service: service,
        sessionRepository: sessionRepository,
        sessionId: "s2-retry",
        worktreePath: worktree.path,
        branchName: "session-002-retry",
        deleteWorktree: true,
        deleteBranch: true,
        force: true,
      );

      expect(retryResult, isA<CleanupSuccess>());
      expect(worktreeService.removeCallCount, equals(2));
      expect(worktreeService.deleteBranchCallCount, equals(2));
    });

    test("dirty worktree without force rejects with mapped issues", () async {
      worktreeService.safetyResult = WorktreeUnsafe(
        issues: [
          UnstagedChanges(),
          BranchMismatch(expected: "session-003", actual: "main"),
        ],
      );

      final result = await _cleanup(
        service: service,
        sessionRepository: sessionRepository,
        sessionId: "s3",
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

      final result = await _cleanup(
        service: service,
        sessionRepository: sessionRepository,
        sessionId: "s4",
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

      final result = await _cleanup(
        service: service,
        sessionRepository: sessionRepository,
        sessionId: "s5",
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

    test("failed branch deletion throws instead of reporting success", () async {
      worktreeService.deleteBranchResult = false;

      await expectLater(
        () => _cleanup(
          service: service,
          sessionRepository: sessionRepository,
          sessionId: "s5-failed",
          worktreePath: "/repo/.worktrees/session-005-failed",
          branchName: "session-005-failed",
          deleteWorktree: false,
          deleteBranch: true,
          force: false,
        ),
        throwsA(
          isA<SessionCleanupFailedException>().having(
            (error) => error.operation,
            "operation",
            SessionCleanupOperation.deleteBranch,
          ),
        ),
      );
    });

    test("identical retry accepts a branch that was already deleted", () async {
      final firstResult = await _cleanup(
        service: service,
        sessionRepository: sessionRepository,
        sessionId: "s5-retry",
        worktreePath: "/repo/.worktrees/session-005-retry",
        branchName: "session-005-retry",
        deleteWorktree: false,
        deleteBranch: true,
        force: false,
      );
      expect(firstResult, isA<CleanupSuccess>());

      worktreeService.deleteBranchResult = false;
      worktreeService.branchExistsResult = false;
      final retryResult = await _cleanup(
        service: service,
        sessionRepository: sessionRepository,
        sessionId: "s5-retry",
        worktreePath: "/repo/.worktrees/session-005-retry",
        branchName: "session-005-retry",
        deleteWorktree: false,
        deleteBranch: true,
        force: false,
      );

      expect(retryResult, isA<CleanupSuccess>());
      expect(worktreeService.deleteBranchCallCount, equals(2));
      expect(worktreeService.branchExistsCallCount, equals(1));
    });

    test("shared worktree rejected when force=false", () async {
      sessionRepository.hasSharingResult = true;

      final result = await _cleanup(
        service: service,
        sessionRepository: sessionRepository,
        sessionId: "s6",
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

      final result = await _cleanup(
        service: service,
        sessionRepository: sessionRepository,
        sessionId: "s6b",
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

      final result = await _cleanup(
        service: service,
        sessionRepository: sessionRepository,
        sessionId: "s7",
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

      final result = await _cleanup(
        service: service,
        sessionRepository: sessionRepository,
        sessionId: "s8",
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

  group("SessionLifecycleService archive binding", () {
    late AppDatabase db;
    late _FakeBridgePlugin plugin;
    late SessionLifecycleService service;

    setUp(() async {
      db = createTestDatabase();
      await db.projectsDao.insertProjectsIfMissing(projectIds: ["/repo"]);
      plugin = _FakeBridgePlugin();
      final repository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      service = SessionLifecycleService(
        worktreeService: _FakeWorktreeService(database: db),
        sessionRepository: repository,
        filesystemRepository: FilesystemRepository(
          filesystemApi: const FilesystemApi(),
          permissionValidator: const FilesystemPermissionValidator(),
        ),
      );
      await db.sessionDao.insertSession(
        sessionId: "root-session",
        backendSessionId: "backend-session",
        projectId: "/repo",
        isDedicated: false,
        createdAt: 1,
        worktreePath: null,
        branchName: null,
        baseBranch: null,
        baseCommit: null,
        lastAgent: null,
        lastAgentModel: null,
        pluginId: "fake",
      );
    });

    tearDown(() => db.close());

    test("archive routes plugin I/O through the stored backend id", () async {
      final update = await service.updateArchiveStatus(
        sessionId: "root-session",
        archived: true,
        deleteWorktree: false,
        deleteBranch: false,
        force: false,
      );
      await Future<void>.delayed(Duration.zero);

      expect(update.session.id, "root-session");
      expect(update.changed, isTrue);
      expect(plugin.lastArchivedSessionId, "backend-session");
      expect((await db.sessionDao.getSession(sessionId: "root-session"))?.archivedAt, isNotNull);
    });

    test("unarchive uses the existing root binding and returns its stable id", () async {
      await db.sessionDao.setArchived(
        sessionId: "root-session",
        archivedAt: 2,
        updatedAt: 2,
        projectionUpdatedAt: 2,
      );

      final update = await service.updateArchiveStatus(
        sessionId: "root-session",
        archived: false,
        deleteWorktree: false,
        deleteBranch: false,
        force: false,
      );

      expect(update.session.id, "root-session");
      expect(update.changed, isTrue);
      expect(plugin.lastArchivedSessionId, isNull);
      expect((await db.sessionDao.getSession(sessionId: "root-session"))?.archivedAt, isNull);
    });
  });
}

Future<CleanupResult> _cleanup({
  required SessionLifecycleService service,
  required _FakeSessionRepository sessionRepository,
  required String sessionId,
  required String worktreePath,
  required String branchName,
  required bool deleteWorktree,
  required bool deleteBranch,
  required bool force,
}) {
  sessionRepository.storedSession = StoredSession(
    id: sessionId,
    backendSessionId: "backend-$sessionId",
    pluginId: "fake",
    projectId: "/repo",
    parentSessionId: null,
    directory: worktreePath,
    worktreePath: worktreePath,
    branchName: branchName,
    isDedicated: true,
    archivedAt: null,
    baseBranch: null,
    baseCommit: null,
  );
  return service.cleanup(
    sessionId: sessionId,
    deleteWorktree: deleteWorktree,
    deleteBranch: deleteBranch,
    force: force,
  );
}

class _FakeSessionRepository implements SessionRepository {
  StoredSession? storedSession;
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
  Future<StoredSession?> getStoredSession({required String sessionId}) async => storedSession;

  @override
  Future<StoredSession> requireActiveStoredSession({
    required String sessionId,
    required SessionOperation operation,
  }) async {
    final session = storedSession;
    if (session == null) {
      throw PluginOperationException.notFound(
        operation.name,
        message: "session $sessionId was not found",
      );
    }
    ensurePluginAvailable(pluginId: session.pluginId, operation: operation);
    return session;
  }

  @override
  void ensurePluginAvailable({required String pluginId, required SessionOperation operation}) {
    if (pluginId == "fake") return;
    throw PluginOperationException(
      operation.name,
      statusCode: 503,
      message: "plugin $pluginId is not running",
    );
  }

  @override
  Future<Session?> getCatalogSession({required String sessionId}) async => null;

  @override
  Future<SessionStatusResponse> getSessionStatuses() async => const SessionStatusResponse(statuses: {});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<String> resolveProjectDirectory({required String projectId}) async => projectId;
}

class _FakeWorktreeService extends WorktreeService {
  WorktreeSafetyResult safetyResult = WorktreeSafe();
  bool removeResult = true;
  bool deleteBranchResult = true;
  bool branchExistsResult = true;

  int checkCallCount = 0;
  int removeCallCount = 0;
  int deleteBranchCallCount = 0;
  int branchExistsCallCount = 0;

  String? lastRemoveWorktreePath;
  bool? lastRemoveForce;
  bool? lastDeleteBranchForce;

  _FakeWorktreeService({required AppDatabase database})
    : super(
        worktreeRepository: singlePluginWorktreeRepository(
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
    required String pluginId,
    required String projectId,
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
    required String projectId,
    required String branchName,
    required bool force,
  }) async {
    deleteBranchCallCount++;
    lastDeleteBranchForce = force;
    return deleteBranchResult;
  }

  @override
  Future<bool> branchExists({
    required String projectId,
    required String branchName,
  }) async {
    branchExistsCallCount++;
    return branchExistsResult;
  }
}

class _FakeBridgePlugin implements NativeProjectsPluginApi {
  String? lastArchivedSessionId;

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
  Future<void> archiveSession({required String sessionId}) async {
    lastArchivedSessionId = sessionId;
  }

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
