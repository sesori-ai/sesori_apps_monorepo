import "dart:io";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/api/filesystem_api.dart";
import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/device_canvas/integration_state.dart";
import "package:sesori_bridge/src/bridge/foundation/filesystem_permission_validator.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/repositories/device_canvas_claim_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/filesystem_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/models/session_operation.dart";
import "package:sesori_bridge/src/bridge/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/bridge/repositories/models/verified_github_login.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/services/archived_session_validator.dart";
import "package:sesori_bridge/src/bridge/services/device_canvas_claim_service.dart";
import "package:sesori_bridge/src/bridge/services/session_cleanup_result.dart";
import "package:sesori_bridge/src/bridge/services/session_lifecycle_service.dart";
import "package:sesori_bridge/src/bridge/services/session_operation_dispatcher.dart";
import "package:sesori_bridge/src/bridge/services/worktree_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_chat_history.dart";
import "../../helpers/test_database.dart";

void main() {
  group("SessionLifecycleService cleanup", () {
    late AppDatabase db;
    late _FakeWorktreeService worktreeService;
    late _FakeSessionRepository sessionRepository;
    late SessionOperationDispatcher operationDispatcher;
    late SessionLifecycleService service;

    setUp(() {
      db = createTestDatabase();
      worktreeService = _FakeWorktreeService(database: db);
      sessionRepository = _FakeSessionRepository();
      operationDispatcher = SessionOperationDispatcher(sessionRepository: sessionRepository);
      service = SessionLifecycleService(
        worktreeService: worktreeService,
        sessionRepository: sessionRepository,
        filesystemRepository: FilesystemRepository(
          filesystemApi: const FilesystemApi(),
          permissionValidator: const FilesystemPermissionValidator(),
        ),
        sessionOperationDispatcher: operationDispatcher,
        archivedSessionValidator: ArchivedSessionValidator(sessionRepository: sessionRepository),
        chatHistoryService: createTestChatHistory().service,
        deviceCanvasClaimService: _claimService(db),
      );
    });

    tearDown(() async {
      await operationDispatcher.dispose();
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
        force: false,
      );

      expect(result, isA<CleanupSuccess>());
      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(0));
    });

    test("missing root binding is an explicit not-found failure", () async {
      await expectLater(
        service.cleanupAlreadyReserved(
          sessionId: "missing",
          deleteWorktree: true,
          force: false,
        ),
        throwsA(isA<PluginOperationException>().having((error) => error.isNotFound, "isNotFound", isTrue)),
      );

      expect(worktreeService.checkCallCount, isZero);
      expect(worktreeService.removeCallCount, isZero);
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
          force: true,
        ),
        throwsA(isA<PluginOperationException>().having((error) => error.statusCode, "statusCode", 503)),
      );

      expect(worktreeService.checkCallCount, isZero);
      expect(worktreeService.removeCallCount, isZero);
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
        force: false,
      );

      expect(result, isA<CleanupSuccess>());
      expect(worktreeService.checkCallCount, equals(1));
      expect(worktreeService.removeCallCount, equals(1));
      expect(worktreeService.lastRemoveWorktreePath, equals("/repo/.worktrees/session-002"));
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

    test("dirty worktree without force rejects with mapped issues", () async {
      worktreeService.safetyResult = WorktreeUnsafe(
        issues: [
          UnstagedChanges(),
        ],
      );

      final result = await _cleanup(
        service: service,
        sessionRepository: sessionRepository,
        sessionId: "s3",
        worktreePath: "/repo/.worktrees/session-003",
        branchName: "session-003",
        deleteWorktree: true,
        force: false,
      );

      expect(result, isA<CleanupRejected>());
      final rejection = (result as CleanupRejected).rejection;
      expect(
        rejection.issues,
        equals(
          const [
            CleanupIssue.unstagedChanges(),
          ],
        ),
      );
      expect(worktreeService.removeCallCount, equals(0));
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
        force: true,
      );

      expect(result, isA<CleanupSuccess>());
      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(1));
      expect(worktreeService.lastRemoveForce, isTrue);
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
        force: false,
      );

      expect(result, isA<CleanupRejected>());
      final rejection = (result as CleanupRejected).rejection;
      expect(rejection.issues, equals(const [CleanupIssue.sharedWorktree()]));
      expect(sessionRepository.hasSharingCallCount, equals(1));
      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(0));
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
        force: true,
      );

      // force=true skips both the shared-worktree check and the safety check;
      // cleanup proceeds so the user can resolve the stalemate.
      expect(result, isA<CleanupSuccess>());
      expect(sessionRepository.hasSharingCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(1));
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
        force: false,
      );

      expect(result, isA<CleanupSuccess>());
      expect(sessionRepository.hasSharingCallCount, equals(1));
      expect(worktreeService.removeCallCount, equals(1));
    });
  });

  group("SessionLifecycleService archive binding", () {
    late AppDatabase db;
    late _FakeBridgePlugin plugin;
    late SessionOperationDispatcher operationDispatcher;
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
      operationDispatcher = SessionOperationDispatcher(sessionRepository: repository);
      service = SessionLifecycleService(
        worktreeService: _FakeWorktreeService(database: db),
        sessionRepository: repository,
        filesystemRepository: FilesystemRepository(
          filesystemApi: const FilesystemApi(),
          permissionValidator: const FilesystemPermissionValidator(),
        ),
        sessionOperationDispatcher: operationDispatcher,
        archivedSessionValidator: ArchivedSessionValidator(sessionRepository: repository),
        chatHistoryService: createTestChatHistory().service,
        deviceCanvasClaimService: _claimService(db),
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

    tearDown(() async {
      await operationDispatcher.dispose();
      await db.close();
    });

    test("archive routes plugin I/O through the stored backend id", () async {
      final claimService = _claimService(db);
      await claimService.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "root-session",
      );

      final update = await service.updateArchiveStatus(
        sessionId: "root-session",
        archived: true,
        deleteWorktree: false,
        force: false,
      );
      await Future<void>.delayed(Duration.zero);

      expect(update.session.id, "root-session");
      expect(update.changed, isTrue);
      expect(plugin.lastArchivedSessionId, "backend-session");
      expect((await db.sessionDao.getSession(sessionId: "root-session"))?.archivedAt, isNotNull);
      expect(await db.deviceCanvasClaimDao.getClaimsForBridge(bridgeId: "bridge-a"), isEmpty);
    });

    test("archived: false on an archived session is refused and keeps it archived", () async {
      await db.sessionDao.setArchived(
        sessionId: "root-session",
        archivedAt: 2,
        updatedAt: 2,
        projectionUpdatedAt: 2,
      );

      await expectLater(
        service.updateArchiveStatus(
          sessionId: "root-session",
          archived: false,
          deleteWorktree: false,
          force: false,
        ),
        throwsA(
          isA<SessionArchivedReadOnlyException>().having(
            (e) => e.rejection,
            "rejection",
            const SessionArchivedRejection(
              sessionId: "root-session",
              reason: SessionArchivedReason.archivedReadOnly,
            ),
          ),
        ),
      );
      expect((await db.sessionDao.getSession(sessionId: "root-session"))?.archivedAt, 2);
    });

    test("archived: false on a non-archived session stays an unchanged no-op", () async {
      final update = await service.updateArchiveStatus(
        sessionId: "root-session",
        archived: false,
        deleteWorktree: false,
        force: false,
      );

      expect(update.session.id, "root-session");
      expect(update.changed, isFalse);
      expect((await db.sessionDao.getSession(sessionId: "root-session"))?.archivedAt, isNull);
    });
  });
}

DeviceCanvasClaimService _claimService(AppDatabase db) {
  return DeviceCanvasClaimService(
    repository: DeviceCanvasClaimRepository(
      claimDao: db.deviceCanvasClaimDao,
      sessionDao: db.sessionDao,
      now: () => DateTime.now().millisecondsSinceEpoch,
    ),
    integrationState: DeviceCanvasIntegrationState(),
  );
}

Future<CleanupResult> _cleanup({
  required SessionLifecycleService service,
  required _FakeSessionRepository sessionRepository,
  required String sessionId,
  required String worktreePath,
  required String branchName,
  required bool deleteWorktree,
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
  return service.cleanupAlreadyReserved(
    sessionId: sessionId,
    deleteWorktree: deleteWorktree,
    force: force,
  );
}

class _FakeSessionRepository() implements SessionRepository {
  StoredSession? storedSession;
  bool hasSharingResult = false;
  int hasSharingCallCount = 0;

  @override
  Future<List<Session>> enrichSessions({
    required List<Session> sessions,
    required VerifiedGithubLogin? verifiedGithubLogin,
  }) async => sessions;

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
  Future<StoredSession> requireRoutableStoredSession({
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
    await ensurePluginRoutable(pluginId: session.pluginId, operation: operation);
    return session;
  }

  @override
  Future<SessionFamilyScope> resolveSessionFamily({
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
    return (rootSessionId: session.id, pluginId: session.pluginId);
  }

  @override
  Future<void> ensurePluginRoutable({required String pluginId, required SessionOperation operation}) async {
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

class _FakeWorktreeService({required AppDatabase database}) extends WorktreeService {
  WorktreeSafetyResult safetyResult = WorktreeSafe();
  bool removeResult = true;

  int checkCallCount = 0;
  int removeCallCount = 0;

  String? lastRemoveWorktreePath;
  bool? lastRemoveForce;

  this
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
}

class _FakeBridgePlugin() implements NativeProjectsPluginApi {
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
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) => throw UnimplementedError();

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required String? userVisibleText,
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
    required String? userVisibleArguments,
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

class _NoopProcessRunner() implements ProcessRunner {
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
