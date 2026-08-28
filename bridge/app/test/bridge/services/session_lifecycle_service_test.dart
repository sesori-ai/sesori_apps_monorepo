import "dart:io";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/filesystem_api.dart";
import "package:sesori_bridge/src/foundation/filesystem_permission_validator.dart";
import "package:sesori_bridge/src/repositories/filesystem_repository.dart";
import "package:sesori_bridge/src/repositories/models/session_operation.dart";
import "package:sesori_bridge/src/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/repositories/models/verified_github_login.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/services/archived_session_validator.dart";
import "package:sesori_bridge/src/services/session_cleanup_result.dart";
import "package:sesori_bridge/src/services/session_lifecycle_service.dart";
import "package:sesori_bridge/src/services/session_operation_dispatcher.dart";
import "package:sesori_bridge/src/services/worktree_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fakes/deletion_worktree_service_fake.dart";
import "../../helpers/fakes/fake_bridge_plugin.dart";
import "../../helpers/test_chat_history.dart";
import "../../helpers/test_database.dart";

void main() {
  group("SessionLifecycleService cleanup", () {
    late AppDatabase db;
    late DeletionWorktreeServiceFake worktreeService;
    late _FakeSessionRepository sessionRepository;
    late SessionOperationDispatcher operationDispatcher;
    late SessionLifecycleService service;

    setUp(() {
      db = createTestDatabase();
      worktreeService = DeletionWorktreeServiceFake();
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
        worktreeService: DeletionWorktreeServiceFake(),
        sessionRepository: repository,
        filesystemRepository: FilesystemRepository(
          filesystemApi: const FilesystemApi(),
          permissionValidator: const FilesystemPermissionValidator(),
        ),
        sessionOperationDispatcher: operationDispatcher,
        archivedSessionValidator: ArchivedSessionValidator(sessionRepository: repository),
        chatHistoryService: createTestChatHistory().service,
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
        lastAgent: "build",
        lastAgentModel: const AgentModel(
          providerID: "provider",
          modelID: "model",
          variant: "high",
        ),
        pluginId: "fake",
        preservePullRequestScope: false,
      );
    });

    tearDown(() async {
      await operationDispatcher.dispose();
      await db.close();
    });

    test("archive routes plugin I/O through the stored backend id", () async {
      final update = await service.updateArchiveStatus(
        sessionId: "root-session",
        archived: true,
        deleteWorktree: false,
        force: false,
      );
      await Future<void>.delayed(Duration.zero);

      expect(update.session.id, "root-session");
      expect(update.session.promptDefaults, isNull);
      expect(update.changed, isTrue);
      expect(plugin.lastArchivedSessionId, "backend-session");
      final stored = await db.sessionDao.getSession(sessionId: "root-session");
      expect(stored?.archivedAt, isNotNull);
      expect(stored?.lastAgent, isNull);
      expect(stored?.lastAgentModel, isNull);
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

class _FakeBridgePlugin() extends FakeBridgePlugin {
  String? get lastArchivedSessionId => lastArchiveSessionId;

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required String? userVisibleText,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) => throw UnimplementedError();

  @override
  Future<PluginSession> renameSession({required String sessionId, required String title}) => throw UnimplementedError();

  @override
  Future<PluginProject> renameProject({required String projectId, required String name}) => throw UnimplementedError();

  @override
  Future<PluginProject> getProject(String projectId) => throw UnimplementedError();
}
