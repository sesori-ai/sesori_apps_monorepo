import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/api/filesystem_api.dart";
import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/device_canvas/integration_state.dart";
import "package:sesori_bridge/src/bridge/device_canvas/protocol.dart";
import "package:sesori_bridge/src/bridge/foundation/filesystem_permission_validator.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/repositories/device_canvas_claim_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/filesystem_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/routing/delete_session_handler.dart";
import "package:sesori_bridge/src/bridge/services/archived_session_validator.dart";
import "package:sesori_bridge/src/bridge/services/device_canvas_claim_service.dart";
import "package:sesori_bridge/src/bridge/services/session_deletion_service.dart";
import "package:sesori_bridge/src/bridge/services/session_lifecycle_service.dart";
import "package:sesori_bridge/src/bridge/services/session_mutation_dispatcher.dart";
import "package:sesori_bridge/src/bridge/services/session_operation_dispatcher.dart";
import "package:sesori_bridge/src/bridge/services/worktree_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_chat_history.dart";
import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

void main() {
  group("DeleteSessionHandler", () {
    late AppDatabase db;
    late _TrackingFakeBridgePlugin plugin;
    late _FakeWorktreeService worktreeService;
    late SessionOperationDispatcher sessionOperationDispatcher;
    late SessionMutationDispatcher sessionMutationDispatcher;
    late DeleteSessionHandler handler;
    late DeviceCanvasClaimService claimService;
    late DeviceCanvasIntegrationState deviceCanvasIntegrationState;
    late List<String> operationLog;
    late TestChatHistory chatHistory;

    setUp(() {
      db = createTestDatabase();
      operationLog = [];
      plugin = _TrackingFakeBridgePlugin(operationLog: operationLog);
      worktreeService = _FakeWorktreeService(database: db, operationLog: operationLog);
      final sessionRepository = singlePluginSessionRepository(
        plugin: plugin,
        sessionDao: db.sessionDao,
        projectsDao: db.projectsDao,
        pullRequestDao: db.pullRequestDao,
        unseenCalculator: const SessionUnseenCalculator(),
      );
      deviceCanvasIntegrationState = DeviceCanvasIntegrationState();
      deviceCanvasIntegrationState.connect(canvasInstanceId: "test", protocolVersion: 1);
      deviceCanvasIntegrationState.replaceInventory([
        _device("ios:booted"),
        _device("ios:child"),
      ]);
      claimService = _claimService(db: db, integrationState: deviceCanvasIntegrationState);
      chatHistory = createTestChatHistory();
      sessionOperationDispatcher = SessionOperationDispatcher(sessionRepository: sessionRepository);
      sessionMutationDispatcher = SessionMutationDispatcher(
        sessionRepository: sessionRepository,
        sessionOperationDispatcher: sessionOperationDispatcher,
        worktreeService: worktreeService,
      );
      final sessionLifecycleService = SessionLifecycleService(
        worktreeService: worktreeService,
        sessionRepository: sessionRepository,
        filesystemRepository: FilesystemRepository(
          filesystemApi: const FilesystemApi(),
          permissionValidator: const FilesystemPermissionValidator(),
        ),
        sessionOperationDispatcher: sessionOperationDispatcher,
        archivedSessionValidator: ArchivedSessionValidator(sessionRepository: sessionRepository),
        chatHistoryService: chatHistory.service,
        deviceCanvasClaimService: claimService,
      );
      handler = DeleteSessionHandler(
        sessionDeletionService: SessionDeletionService(
          sessionLifecycleService: sessionLifecycleService,
          sessionMutationDispatcher: sessionMutationDispatcher,
          chatHistoryService: chatHistory.service,
          deviceCanvasClaimService: claimService,
        ),
      );
    });

    tearDown(() async {
      await sessionOperationDispatcher.dispose();
      await sessionMutationDispatcher.dispose();
      await claimService.dispose();
      await deviceCanvasIntegrationState.dispose();
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

    test("deleteWorktree=false: plugin+db delete, no git ops", () async {
      await _insertSession(
        db: db,
        sessionId: "s1",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-001",
        branchName: "session-001",
      );
      await claimService.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:booted",
        sessionId: "s1",
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
      expect(await db.deviceCanvasClaimDao.getClaimsForBridge(bridgeId: "bridge-a"), isEmpty);
      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(0));
      expect(operationLog, equals(["pluginDelete"]));
    });

    test("publishes claim removals for deleted session subtree after rows are gone", () async {
      await _insertSession(
        db: db,
        sessionId: "root",
        projectId: "/repo",
        worktreePath: null,
        branchName: null,
      );
      await _insertChildSession(db: db, sessionId: "child", parentSessionId: "root", projectId: "/repo");
      final removals = <DeviceCanvasClaimRemoved>[];
      final subscription = claimService.changes.listen((change) {
        if (change is DeviceCanvasClaimRemoved) removals.add(change);
      });
      addTearDown(subscription.cancel);
      await claimService.claim(bridgeId: "bridge-a", deviceKey: "ios:booted", sessionId: "root");
      await claimService.claim(bridgeId: "bridge-a", deviceKey: "ios:child", sessionId: "child");

      final response = await handler.handle(
        makeRequest("DELETE", "/session/delete"),
        body: const DeleteSessionRequest(
          sessionId: "root",
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, isA<SuccessEmptyResponse>());
      expect(removals.map((removal) => removal.deviceKey).toSet(), equals({"ios:booted", "ios:child"}));
      expect(await db.sessionDao.getSession(sessionId: "root"), isNull);
      expect(await db.sessionDao.getSession(sessionId: "child"), isNull);
      expect(await db.deviceCanvasClaimDao.getClaimsForBridge(bridgeId: "bridge-a"), isEmpty);
    });

    test("late claim after backend delete starts is removed by the persisted delete transaction", () async {
      await _insertSession(
        db: db,
        sessionId: "late-claim",
        projectId: "/repo",
        worktreePath: null,
        branchName: null,
      );
      final pluginDeleteGate = Completer<void>();
      plugin.deleteSessionGate = pluginDeleteGate.future;
      final changes = <DeviceCanvasClaimChange>[];
      final subscription = claimService.changes.listen(changes.add);
      addTearDown(subscription.cancel);

      final deletion = handler.handle(
        makeRequest("DELETE", "/session/delete"),
        body: const DeleteSessionRequest(
          sessionId: "late-claim",
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      await plugin.deleteSessionStarted.future;

      await claimService.claim(bridgeId: "bridge-a", deviceKey: "ios:booted", sessionId: "late-claim");
      pluginDeleteGate.complete();

      expect(await deletion, isA<SuccessEmptyResponse>());
      expect(changes, [isA<DeviceCanvasClaimUpdated>(), isA<DeviceCanvasClaimRemoved>()]);
      expect(await db.sessionDao.getSession(sessionId: "late-claim"), isNull);
      expect(await db.deviceCanvasClaimDao.getClaimsForBridge(bridgeId: "bridge-a"), isEmpty);
    });

    test("late descendant and claim are included in persisted subtree cleanup", () async {
      await _insertSession(
        db: db,
        sessionId: "root",
        projectId: "/repo",
        worktreePath: null,
        branchName: null,
      );
      final pluginDeleteGate = Completer<void>();
      plugin.deleteSessionGate = pluginDeleteGate.future;
      final removals = <DeviceCanvasClaimRemoved>[];
      final subscription = claimService.changes
          .where((change) => change is DeviceCanvasClaimRemoved)
          .cast<DeviceCanvasClaimRemoved>()
          .listen(removals.add);
      addTearDown(subscription.cancel);

      final deletion = handler.handle(
        makeRequest("DELETE", "/session/delete"),
        body: const DeleteSessionRequest(
          sessionId: "root",
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      await plugin.deleteSessionStarted.future;

      await _insertChildSession(
        db: db,
        sessionId: "late-child",
        parentSessionId: "root",
        projectId: "/repo",
      );
      await claimService.claim(
        bridgeId: "bridge-a",
        deviceKey: "ios:child",
        sessionId: "late-child",
      );
      pluginDeleteGate.complete();

      expect(await deletion, isA<SuccessEmptyResponse>());
      expect(removals.map((removal) => removal.deviceKey), ["ios:child"]);
      expect(await db.sessionDao.getSession(sessionId: "late-child"), isNull);
      expect(await db.deviceCanvasClaimDao.getClaimsForBridge(bridgeId: "bridge-a"), isEmpty);
    });

    test("missing binding returns 404 before plugin or cleanup calls", () async {
      final response = await handler.handleInternal(
        makeRequest(
          "DELETE",
          "/session/delete",
          body: jsonEncode(
            const DeleteSessionRequest(
              sessionId: "ghost",
              deleteWorktree: true,
              deleteBranch: false,
              force: false,
            ).toJson(),
          ),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, 404);
      expect(plugin.lastDeleteSessionId, isNull);
      expect(worktreeService.checkCallCount, 0);
      expect(worktreeService.removeCallCount, 0);
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
      expect(worktreeService.removeCallCount, equals(1));
      expect(worktreeService.lastRemoveProjectId, equals("/repo"));
      expect(worktreeService.lastRemoveWorktreePath, equals("/repo/.worktrees/session-002"));
      expect(worktreeService.lastRemoveForce, isFalse);
      expect(plugin.lastDeleteSessionId, equals("s2"));
      expect(await db.sessionDao.getSession(sessionId: "s2"), isNull);
      expect(operationLog, equals(["checkSafety", "removeWorktree", "pluginDelete"]));
    });

    test("failed worktree removal preserves the session for retry", () async {
      final worktree = Directory.systemTemp.createTempSync("delete_cleanup_failure_");
      addTearDown(() {
        if (worktree.existsSync()) worktree.deleteSync(recursive: true);
      });
      await _insertSession(
        db: db,
        sessionId: "s2-failed",
        projectId: "/repo",
        worktreePath: worktree.path,
        branchName: "session-002-failed",
      );
      worktreeService.safetyResult = WorktreeSafe();
      worktreeService.removeResult = false;

      await expectLater(
        () => handler.handle(
          makeRequest("DELETE", "/session/delete"),
          body: const DeleteSessionRequest(
            sessionId: "s2-failed",
            deleteWorktree: true,
            deleteBranch: false,
            force: false,
          ),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<SessionCleanupFailedException>()),
      );

      expect(plugin.lastDeleteSessionId, isNull);
      expect(await db.sessionDao.getSession(sessionId: "s2-failed"), isNotNull);
      expect(operationLog, equals(["checkSafety", "removeWorktree"]));
    });

    test("legacy deleteBranch=true is rejected before deletion", () async {
      await _insertSession(
        db: db,
        sessionId: "s3",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-003",
        branchName: "session-003",
      );

      await expectLater(
        () => handler.handle(
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
        ),
        throwsA(isA<RelayResponse>().having((response) => response.status, "status", 422)),
      );

      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(0));
      expect(plugin.lastDeleteSessionId, isNull);
      expect(await db.sessionDao.getSession(sessionId: "s3"), isNotNull);
      expect(operationLog, isEmpty);
    });

    test("legacy combined cleanup is rejected before worktree removal", () async {
      await _insertSession(
        db: db,
        sessionId: "s4",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-004",
        branchName: "session-004",
      );
      worktreeService.safetyResult = WorktreeSafe();

      await expectLater(
        () => handler.handle(
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
        ),
        throwsA(isA<RelayResponse>().having((response) => response.status, "status", 422)),
      );

      expect(worktreeService.checkCallCount, isZero);
      expect(worktreeService.removeCallCount, isZero);
      expect(plugin.lastDeleteSessionId, isNull);
      expect(await db.sessionDao.getSession(sessionId: "s4"), isNotNull);
      expect(operationLog, isEmpty);
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
        ],
      );
      final removals = <DeviceCanvasClaimRemoved>[];
      final subscription = claimService.changes.listen((change) {
        if (change is DeviceCanvasClaimRemoved) removals.add(change);
      });
      addTearDown(subscription.cancel);
      await claimService.claim(bridgeId: "bridge-a", deviceKey: "ios:booted", sessionId: "s5");

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
      expect(plugin.lastDeleteSessionId, isNull);
      expect(await db.sessionDao.getSession(sessionId: "s5"), isNotNull);
      expect(await db.deviceCanvasClaimDao.getClaimsForBridge(bridgeId: "bridge-a"), hasLength(1));
      expect(removals, isEmpty);
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
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, isA<SuccessEmptyResponse>());
      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(0));
      expect(plugin.lastDeleteSessionId, equals("s7"));
      expect(await db.sessionDao.getSession(sessionId: "s7"), isNull);
      expect(operationLog, equals(["pluginDelete"]));
    });

    test("stored plugin mismatch returns 503 before plugin I/O or cleanup", () async {
      await _insertSession(
        db: db,
        sessionId: "s9",
        projectId: "/repo",
        worktreePath: "/repo/.worktrees/session-009",
        branchName: "session-009",
        pluginId: "stopped-plugin",
      );

      final response = await handler.handleInternal(
        makeRequest(
          "DELETE",
          "/session/delete",
          body: jsonEncode(
            const DeleteSessionRequest(
              sessionId: "s9",
              deleteWorktree: true,
              deleteBranch: false,
              force: false,
            ).toJson(),
          ),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, 503);
      expect(plugin.lastDeleteSessionId, isNull);
      expect(worktreeService.checkCallCount, equals(0));
      expect(worktreeService.removeCallCount, equals(0));
      expect(await db.sessionDao.getSession(sessionId: "s9"), isNotNull);
      expect(operationLog, isEmpty);
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
      await claimService.claim(bridgeId: "bridge-a", deviceKey: "ios:booted", sessionId: "s10");
      final removals = <DeviceCanvasClaimRemoved>[];
      final subscription = claimService.changes.listen((change) {
        if (change is DeviceCanvasClaimRemoved) removals.add(change);
      });
      addTearDown(subscription.cancel);

      await expectLater(
        () => handler.handle(
          makeRequest("DELETE", "/session/delete"),
          body: const DeleteSessionRequest(
            sessionId: "s10",
            deleteWorktree: true,
            deleteBranch: false,
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
      expect(await db.sessionDao.getSession(sessionId: "s10"), isNotNull);
      expect(await db.deviceCanvasClaimDao.getClaimsForBridge(bridgeId: "bridge-a"), hasLength(1));
      expect(removals, isEmpty);
      expect(operationLog, equals(["checkSafety", "removeWorktree", "pluginDelete"]));
    });

    test("11) plugin delete 404: tolerated, DB row still removed", () async {
      await _insertSession(
        db: db,
        sessionId: "s11",
        projectId: "/repo",
        worktreePath: null,
        branchName: null,
      );
      plugin.throwOnDeleteSessionError = PluginApiException("/session/s11", 404);

      final response = await handler.handle(
        makeRequest("DELETE", "/session/delete"),
        body: const DeleteSessionRequest(
          sessionId: "s11",
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, isA<SuccessEmptyResponse>());
      expect(await db.sessionDao.getSession(sessionId: "s11"), isNull);
    });

    test("12) plugin delete not-found from a non-HTTP plugin: tolerated, DB row still removed", () async {
      await _insertSession(
        db: db,
        sessionId: "s12",
        projectId: "/repo",
        worktreePath: null,
        branchName: null,
      );
      plugin.throwOnDeleteSessionError = const PluginOperationException.notFound("deleteSession");

      final response = await handler.handle(
        makeRequest("DELETE", "/session/delete"),
        body: const DeleteSessionRequest(
          sessionId: "s12",
          deleteWorktree: false,
          deleteBranch: false,
          force: false,
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, isA<SuccessEmptyResponse>());
      expect(await db.sessionDao.getSession(sessionId: "s12"), isNull);
    });
  });
}

DeviceCanvasDescriptor _device(String deviceKey) {
  return DeviceCanvasDescriptor(
    deviceKey: deviceKey,
    platform: DeviceCanvasPlatform.ios,
    displayName: "iPhone",
    runtimeDescription: "iOS 18",
    modelDescription: "iPhone",
    dimensions: const DeviceCanvasDimensions(width: 390, height: 844),
    orientation: DeviceCanvasOrientation.portrait,
    capabilities: const DeviceCanvasCapabilities(localView: true, remoteVideo: true, remoteControl: true, input: true),
  );
}

DeviceCanvasClaimService _claimService({
  required AppDatabase db,
  required DeviceCanvasIntegrationState integrationState,
}) {
  return DeviceCanvasClaimService(
    repository: DeviceCanvasClaimRepository(
      claimDao: db.deviceCanvasClaimDao,
      sessionDao: db.sessionDao,
      now: () => DateTime.now().millisecondsSinceEpoch,
    ),
    integrationState: integrationState,
  );
}

Future<void> _insertSession({
  required AppDatabase db,
  required String sessionId,
  required String projectId,
  required String? worktreePath,
  required String? branchName,
  String pluginId = "fake",
}) async {
  await db.projectsDao.insertProjectsIfMissing(projectIds: [projectId]); // satisfy v5 FK constraint
  await db.sessionDao.insertSession(
    pluginId: pluginId,
    sessionId: sessionId,
    backendSessionId: sessionId,
    projectId: projectId,
    isDedicated: true,
    createdAt: 1,
    worktreePath: worktreePath,
    branchName: branchName,
    baseBranch: null,
    baseCommit: null,

    lastAgent: null,
    lastAgentModel: null,
  );
}

Future<void> _insertChildSession({
  required AppDatabase db,
  required String sessionId,
  required String parentSessionId,
  required String projectId,
}) async {
  await db.sessionDao.insertObservedChild(
    sessionId: sessionId,
    backendSessionId: sessionId,
    projectId: projectId,
    parentSessionId: parentSessionId,
    directory: projectId,
    catalogTitle: null,
    archivedAt: null,
    createdAt: 1,
    updatedAt: 1,
    projectionUpdatedAt: 1,
    pluginId: "fake",
  );
}

class _FakeWorktreeService({required AppDatabase database, required final List<String> operationLog})
    extends WorktreeService {
  WorktreeSafetyResult safetyResult = WorktreeSafe();
  bool removeResult = true;

  int checkCallCount = 0;
  int removeCallCount = 0;

  String? lastCheckWorktreePath;
  String? lastRemoveProjectId;
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
    operationLog.add("checkSafety");
    lastCheckWorktreePath = worktreePath;
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
    operationLog.add("removeWorktree");
    lastRemoveProjectId = projectId;
    lastRemoveWorktreePath = worktreePath;
    lastRemoveForce = force;
    return removeResult;
  }
}

class _FakeBridgePlugin() extends FakeBridgePlugin {
  @override
  Future<void> deleteWorkspace({
    required String projectId,
    required String worktreePath,
  }) async {}
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

class _TrackingFakeBridgePlugin({required final List<String> operationLog}) extends FakeBridgePlugin {
  final Completer<void> deleteSessionStarted = Completer<void>();
  Future<void>? deleteSessionGate;

  @override
  Future<void> deleteSession(String sessionId) async {
    operationLog.add("pluginDelete");
    if (!deleteSessionStarted.isCompleted) deleteSessionStarted.complete();
    final gate = deleteSessionGate;
    if (gate != null) await gate;
    await super.deleteSession(sessionId);
  }
}
