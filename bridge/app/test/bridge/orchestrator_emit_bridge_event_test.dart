import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:clock/clock.dart";
import "package:cryptography/cryptography.dart";
import "package:http/http.dart" as http;
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/database/tables/pull_requests_table.dart";
import "package:sesori_bridge/src/auth/token_refresher.dart";
import "package:sesori_bridge/src/bridge/api/filesystem_api.dart";
import "package:sesori_bridge/src/bridge/api/gh_pull_request.dart";
import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/filesystem_permission_validator.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/metadata_service.dart";
import "package:sesori_bridge/src/bridge/models/bridge_config.dart";
import "package:sesori_bridge/src/bridge/models/session_metadata.dart";
import "package:sesori_bridge/src/bridge/orchestrator.dart";
import "package:sesori_bridge/src/bridge/relay_client.dart";
import "package:sesori_bridge/src/bridge/repositories/agent_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/filesystem_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/health_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/mappers/plugin_session_mapper.dart";
import "package:sesori_bridge/src/bridge/repositories/models/session_operation.dart";
import "package:sesori_bridge/src/bridge/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/bridge/repositories/permission_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/pr_source_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/project_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/provider_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/question_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/worktree_repository.dart";
import "package:sesori_bridge/src/bridge/services/pr_sync_service.dart";
import "package:sesori_bridge/src/bridge/services/project_activity_service.dart";
import "package:sesori_bridge/src/bridge/services/project_initialization_service.dart";
import "package:sesori_bridge/src/bridge/services/session_creation_service.dart";
import "package:sesori_bridge/src/bridge/services/session_event_enrichment_service.dart";
import "package:sesori_bridge/src/bridge/services/session_mutation_dispatcher.dart";
import "package:sesori_bridge/src/bridge/services/session_unseen_service.dart";
import "package:sesori_bridge/src/bridge/services/session_view_tracker.dart";
import "package:sesori_bridge/src/bridge/services/worktree_service.dart";
import "package:sesori_bridge/src/control/control_status_notifier.dart";
import "package:sesori_bridge/src/foundation/control_channel_client.dart";
import "package:sesori_bridge/src/push/completion_notifier.dart";
import "package:sesori_bridge/src/push/completion_push_listener.dart";
import "package:sesori_bridge/src/push/maintenance_push_listener.dart";
import "package:sesori_bridge/src/push/push_dispatcher.dart";
import "package:sesori_bridge/src/push/push_maintenance_telemetry.dart";
import "package:sesori_bridge/src/push/push_notification_client.dart";
import "package:sesori_bridge/src/push/push_notification_content_builder.dart";
import "package:sesori_bridge/src/push/push_rate_limiter.dart";
import "package:sesori_bridge/src/push/push_session_state_tracker.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" hide PermissionReply;
import "package:test/test.dart";

import "../helpers/fake_filesystem_api.dart";
import "../helpers/fake_git_cli_api.dart";
import "../helpers/restart_test_support.dart";
import "../helpers/test_database.dart";
import "../helpers/test_helpers.dart";
import "routing/get_session_diffs_handler_test_helpers.dart";

void main() {
  test("orchestrator routes activity and silently auto-approves yolo permissions", () async {
    final relayServer = await TestRelayServer.start();
    final database = createTestDatabase();
    final plugin = _EventPlugin(
      pendingPermissions: const [
        PluginPendingPermission(
          id: "pending-permission",
          sessionID: "pending-child-session",
          displaySessionId: "pending-root-session",
          tool: "bash",
          description: "resume a command",
        ),
      ],
    );
    final pushSubsystem = _createPushSubsystem();
    final fakePrSyncService = _FakePrSyncService();
    final sessionRepository = SessionRepository(
      plugin: plugin,
      sessionDao: database.sessionDao,
      projectsDao: database.projectsDao,
      pullRequestDao: database.pullRequestDao,
      gitCliApi: FakeGitCliApi(),
      unseenCalculator: const SessionUnseenCalculator(),
    );
    final projectRepository = ProjectRepository(
      gitCliApi: FakeGitCliApi(),
      plugin: plugin,
      projectsDao: database.projectsDao,
      sessionDao: database.sessionDao,
      unseenCalculator: const SessionUnseenCalculator(),
      filesystemApi: FakeFilesystemApi(),
    );
    final permissionRepository = PermissionRepository(plugin: plugin, sessionDao: database.sessionDao);
    final worktreeService = WorktreeService(
      worktreeRepository: WorktreeRepository(
        projectsDao: database.projectsDao,
        sessionDao: database.sessionDao,
        gitApi: GitCliApi(
          processRunner: FakeProcessRunner(),
          gitPathExists: ({required String gitPath}) => true,
        ),
        plugin: plugin,
      ),
    );
    final relayClient = RelayClient(
      relayURL: "ws://127.0.0.1:${relayServer.port}",
      accessTokenProvider: FakeAccessTokenProvider(),
      bridgeIdProvider: FakeBridgeIdProvider(),
    );
    final sessionTitleService = SessionMutationDispatcher(sessionRepository: sessionRepository);
    final sessionEventEnrichmentService = SessionEventEnrichmentService(
      sessionRepository: sessionRepository,
      sessionMutationDispatcher: sessionTitleService,
      failureReporter: FakeFailureReporter(),
    );

    final projectActivityService = ProjectActivityService(
      projectRepository: projectRepository,
      now: () => 1234,
    );
    final sessionViewTracker = SessionViewTracker();
    final unseenRepository = SessionUnseenRepository(
      plugin: plugin,
      sessionDao: database.sessionDao,
      projectsDao: database.projectsDao,
      db: database,
      calculator: const SessionUnseenCalculator(),
    );
    final sessionUnseenService = _GatedSessionUnseenService(
      unseenRepository: unseenRepository,
      projectRepository: projectRepository,
      viewTracker: sessionViewTracker,
      now: () => 1234,
    );
    await sessionUnseenService.recordSessionCreated(
      sessionId: "root-session",
      projectId: "project-123",
      sessionDirectory: "/tmp/project-123",
      parentId: null,
    );
    expect(await unseenRepository.isUnseen(sessionId: "root-session"), isTrue);
    final orchestrator = Orchestrator(
      config: BridgeConfig(
        relayURL: "ws://127.0.0.1:${relayServer.port}",
        pluginEndpoint: "http://127.0.0.1:4096",
        authBackendURL: "http://127.0.0.1:8080",
        sseReplayWindow: const Duration(minutes: 1),
        yolo: true,
      ),
      client: relayClient,
      plugin: plugin,
      sessionCreationService: SessionCreationService(
        metadataService: _FakeMetadataService(),
        worktreeService: worktreeService,
        sessionRepository: sessionRepository,
        sessionMutationDispatcher: sessionTitleService,
      ),
      pushDispatcher: pushSubsystem.dispatcher,
      completionListener: pushSubsystem.completionListener,
      maintenanceListener: pushSubsystem.maintenanceListener,
      accessTokenProvider: FakeAccessTokenProvider(),
      tokenRefresher: _FakeTokenRefresher(),
      bridgeRegistrationService: createFakeBridgeRegistrationService(),
      failureReporter: FakeFailureReporter(),
      prSyncService: fakePrSyncService,
      sessionRepository: sessionRepository,
      projectRepository: projectRepository,
      sessionUnseenService: sessionUnseenService,
      sessionViewTracker: sessionViewTracker,
      filesystemRepository: FilesystemRepository(
        filesystemApi: const FilesystemApi(),
        permissionValidator: const FilesystemPermissionValidator(),
      ),
      gitCliApi: GitCliApi(
        processRunner: ProcessRunner(),
        gitPathExists: ({required String gitPath}) => gitPath.isNotEmpty,
      ),
      projectInitializationService: ProjectInitializationService(
        worktreeRepository: WorktreeRepository(
          projectsDao: database.projectsDao,
          sessionDao: database.sessionDao,
          plugin: plugin,
          gitApi: GitCliApi(
            processRunner: ProcessRunner(),
            gitPathExists: ({required String gitPath}) => false,
          ),
        ),
        filesystemRepository: FilesystemRepository(
          filesystemApi: const FilesystemApi(),
          permissionValidator: const FilesystemPermissionValidator(),
        ),
      ),
      projectActivityService: projectActivityService,
      healthRepository: HealthRepository(
        plugin: plugin,
        bridgeVersion: "0.0.0-test",
        filesystemAccessOk: true,
      ),
      providerRepository: ProviderRepository(plugin: plugin, projectsDao: database.projectsDao),
      agentRepository: AgentRepository(plugin: plugin, projectsDao: database.projectsDao),
      permissionRepository: permissionRepository,
      questionRepository: QuestionRepository(
        plugin: plugin,
        sessionDao: database.sessionDao,
        projectsDao: database.projectsDao,
      ),
      worktreeService: worktreeService,
      sessionEventEnrichmentService: sessionEventEnrichmentService,
      sessionMutationDispatcher: sessionTitleService,
      restartService: buildTestRestartService(),
      statusNotifier: null,
    );

    final session = orchestrator.create();
    final runFuture = session.run();

    final bridgeSocket = await relayServer.nextClient();
    final messages = bridgeSocket.asBroadcastStream();

    await _waitForCondition(
      check: () => plugin.permissionReplies.length == 1,
      failureMessage: "Timed out waiting for pending permission auto-approval",
    );
    expect(
      plugin.permissionReplies.single,
      equals(
        (
          requestId: "pending-permission",
          sessionId: "pending-child-session",
          reply: PluginPermissionReply.once,
        ),
      ),
    );

    const connID = 7;
    bridgeSocket.add(jsonEncode(<String, Object>{"type": "phone_connected", "connId": connID}));

    final crypto = RelayCryptoService();
    final phoneKp = await crypto.generateKeyPair();
    final phonePub = await phoneKp.extractPublicKey();
    final kxMessage = RelayMessage.keyExchange(
      publicKey: base64Url.encode(phonePub.bytes).replaceAll("=", ""),
    );
    bridgeSocket.add(_withConnID(connID: connID, payload: utf8.encode(jsonEncode(kxMessage.toJson()))));

    final readyFrame = await _nextBinaryMessage(messages: messages);
    final roomKey = await _extractRoomKeyFromReady(
      framedWithConnID: readyFrame,
      phoneKp: phoneKp,
    );

    final encryptor = crypto.createSessionEncryptor(SecretKey(roomKey));
    final unknownControlFrame = await frame(
      utf8.encode(jsonEncode(const <String, Object>{"type": "future_control"})),
      encryptor: encryptor,
    );
    bridgeSocket.add(_withConnID(connID: connID, payload: unknownControlFrame));
    final subscribeFrame = await frame(
      utf8.encode(jsonEncode(const RelayMessage.sseSubscribe(path: "/events").toJson())),
      encryptor: encryptor,
    );
    bridgeSocket.add(_withConnID(connID: connID, payload: subscribeFrame));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final persistenceStarted = Completer<void>();
    final releasePersistence = Completer<void>();
    sessionUnseenService.gateSession(
      sessionId: "ordered-session",
      started: persistenceStarted,
      release: releasePersistence.future,
    );
    var deliveredWhilePersistenceBlocked = false;
    final orderedCreatedFuture =
        _waitForEventType(
          messages: messages,
          roomKey: roomKey,
          expectedType: "session.created",
        ).then((delivered) {
          deliveredWhilePersistenceBlocked = delivered;
          return delivered;
        });
    plugin.add(
      const BridgeSseSessionCreated(
        info: {
          "id": "ordered-session",
          "projectID": "ordered-project",
          "directory": "/tmp/ordered-project",
          "parentID": null,
          "title": "ordered session",
          "time": {"created": 1, "updated": 1, "archived": null},
          "summary": null,
        },
      ),
    );
    await persistenceStarted.future;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final deliveredBeforeRelease = deliveredWhilePersistenceBlocked;
    releasePersistence.complete();
    expect(await orderedCreatedFuture, isTrue);
    expect(deliveredBeforeRelease, isFalse);

    final sentByteCounts = <int>[];
    final sentBytesSubscription = session.bytesSent.listen(sentByteCounts.add);

    plugin.pendingPermissions.add(
      const PluginPendingPermission(
        id: "summary-permission",
        sessionID: "pending-child-session",
        displaySessionId: "pending-root-session",
        tool: "bash",
        description: "update the project summary",
      ),
    );
    final projectsSummaryFuture = _waitForEventType(
      messages: messages,
      roomKey: roomKey,
      expectedType: "projects.summary",
    );
    plugin.add(const BridgeSseProjectUpdated());

    await _waitForCondition(
      check: () => plugin.permissionReplies.length == 2,
      failureMessage: "Timed out waiting for project-summary permission auto-approval",
    );
    expect(
      await projectsSummaryFuture,
      isTrue,
      reason: "an unknown control union must not prevent a following valid subscription",
    );
    final bytesAfterSummary = sentByteCounts.length;

    plugin.add(
      const BridgeSsePermissionAsked(
        requestID: "summary-permission",
        sessionID: "pending-child-session",
        displaySessionId: "pending-root-session",
        tool: "bash",
        description: "update the project summary",
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(plugin.permissionReplies, hasLength(2), reason: "queued permission events must not reply twice");
    expect(sentByteCounts, hasLength(bytesAfterSummary));

    plugin.add(
      const BridgeSsePermissionAsked(
        requestID: "permission-1",
        sessionID: "child-session",
        displaySessionId: "root-session",
        tool: "bash",
        description: "run a command",
      ),
    );

    await _waitForCondition(
      check: () => plugin.permissionReplies.length == 3,
      failureMessage: "Timed out waiting for permission auto-approval",
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(
      plugin.permissionReplies,
      equals([
        (
          requestId: "pending-permission",
          sessionId: "pending-child-session",
          reply: PluginPermissionReply.once,
        ),
        (
          requestId: "summary-permission",
          sessionId: "pending-child-session",
          reply: PluginPermissionReply.once,
        ),
        (
          requestId: "permission-1",
          sessionId: "child-session",
          reply: PluginPermissionReply.once,
        ),
      ]),
    );
    expect(
      sentByteCounts,
      hasLength(bytesAfterSummary),
      reason: "YOLO permission requests must not reach clients",
    );

    plugin.add(
      const BridgeSsePermissionReplied(
        requestID: "permission-1",
        sessionID: "child-session",
        displaySessionId: "root-session",
        reply: "once",
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(
      sentByteCounts,
      hasLength(bytesAfterSummary),
      reason: "YOLO permission replies must not reach clients",
    );
    expect(
      await unseenRepository.isUnseen(sessionId: "root-session"),
      isTrue,
      reason: "YOLO permission replies must not clear unseen activity",
    );
    await sentBytesSubscription.cancel();

    await projectActivityService.openProject(path: "project-activity");
    final projectUpdated = await _waitForEventType(
      messages: messages,
      roomKey: roomKey,
      expectedType: "project.updated",
    );
    expect(projectUpdated, isTrue);

    fakePrSyncService.emitProjectChange(projectId: "project-123");

    final found = await _waitForEventType(
      messages: messages,
      roomKey: roomKey,
      expectedType: "sessions.updated",
    );
    expect(found, isTrue);

    await _insertRootSessionBinding(
      database: database,
      pluginId: plugin.id,
      sessionId: "delete-session",
      backendSessionId: "backend-delete-session",
    );
    await sessionTitleService.deleteSession(sessionId: "delete-session");
    final deleted = await _waitForEventType(
      messages: messages,
      roomKey: roomKey,
      expectedType: "session.deleted",
    );
    expect(deleted, isTrue);
    expect(plugin.deletedSessionIds, equals(["backend-delete-session"]));

    await session.cancel();
    await runFuture.timeout(const Duration(seconds: 5));
    await plugin.close();
    await database.close();
    await relayServer.close();
  });

  test("pre-seeds and forwards projects summary to push dispatcher", () async {
    final relayServer = await TestRelayServer.start();
    final database = createTestDatabase();
    final pushDispatcher = _CapturingPushDispatcher();
    final pushListeners = _createPushListeners(
      tracker: pushDispatcher.tracker,
      completionNotifier: pushDispatcher.completionNotifier,
      rateLimiter: pushDispatcher.rateLimiter,
      telemetryBuilder: pushDispatcher.telemetryBuilder,
      dispatcher: pushDispatcher,
    );
    final plugin = _SummaryPlugin(
      onSubscribe: () {
        expect(pushDispatcher.events.length, 1);
      },
    );
    final fakePrSyncService = _FakePrSyncService();
    final sessionRepository = SessionRepository(
      plugin: plugin,
      sessionDao: database.sessionDao,
      projectsDao: database.projectsDao,
      pullRequestDao: database.pullRequestDao,
      gitCliApi: FakeGitCliApi(),
      unseenCalculator: const SessionUnseenCalculator(),
    );
    final relayClient = RelayClient(
      relayURL: "ws://127.0.0.1:${relayServer.port}",
      accessTokenProvider: FakeAccessTokenProvider(),
      bridgeIdProvider: FakeBridgeIdProvider(),
    );
    final sessionTitleService = SessionMutationDispatcher(sessionRepository: sessionRepository);
    final sessionEventEnrichmentService = SessionEventEnrichmentService(
      sessionRepository: sessionRepository,
      sessionMutationDispatcher: sessionTitleService,
      failureReporter: FakeFailureReporter(),
    );
    final projectRepository = ProjectRepository(
      gitCliApi: FakeGitCliApi(),
      plugin: plugin,
      projectsDao: database.projectsDao,
      sessionDao: database.sessionDao,
      unseenCalculator: const SessionUnseenCalculator(),
      filesystemApi: FakeFilesystemApi(),
    );
    final permissionRepository = PermissionRepository(plugin: plugin, sessionDao: database.sessionDao);
    final worktreeService = WorktreeService(
      worktreeRepository: WorktreeRepository(
        projectsDao: database.projectsDao,
        sessionDao: database.sessionDao,
        gitApi: GitCliApi(
          processRunner: FakeProcessRunner(),
          gitPathExists: ({required String gitPath}) => true,
        ),
        plugin: plugin,
      ),
    );

    final orchestrator = Orchestrator(
      config: BridgeConfig(
        relayURL: "ws://127.0.0.1:${relayServer.port}",
        pluginEndpoint: "http://127.0.0.1:4096",
        authBackendURL: "http://127.0.0.1:8080",
        sseReplayWindow: const Duration(minutes: 1),
        yolo: false,
      ),
      client: relayClient,
      plugin: plugin,
      sessionCreationService: SessionCreationService(
        metadataService: _FakeMetadataService(),
        worktreeService: worktreeService,
        sessionRepository: sessionRepository,
        sessionMutationDispatcher: sessionTitleService,
      ),
      pushDispatcher: pushDispatcher,
      completionListener: pushListeners.completionListener,
      maintenanceListener: pushListeners.maintenanceListener,
      accessTokenProvider: FakeAccessTokenProvider(),
      tokenRefresher: _FakeTokenRefresher(),
      bridgeRegistrationService: createFakeBridgeRegistrationService(),
      failureReporter: FakeFailureReporter(),
      prSyncService: fakePrSyncService,
      sessionRepository: sessionRepository,
      projectRepository: projectRepository,
      sessionUnseenService: SessionUnseenService(
        unseenRepository: SessionUnseenRepository(
          plugin: plugin,
          sessionDao: database.sessionDao,
          projectsDao: database.projectsDao,
          db: database,
          calculator: const SessionUnseenCalculator(),
        ),
        projectRepository: ProjectRepository(
          gitCliApi: FakeGitCliApi(),
          plugin: plugin,
          projectsDao: database.projectsDao,
          sessionDao: database.sessionDao,
          unseenCalculator: const SessionUnseenCalculator(),
          filesystemApi: FakeFilesystemApi(),
        ),
        viewTracker: SessionViewTracker(),
      ),
      sessionViewTracker: SessionViewTracker(),
      filesystemRepository: FilesystemRepository(
        filesystemApi: const FilesystemApi(),
        permissionValidator: const FilesystemPermissionValidator(),
      ),
      gitCliApi: GitCliApi(
        processRunner: ProcessRunner(),
        gitPathExists: ({required String gitPath}) => gitPath.isNotEmpty,
      ),
      projectInitializationService: ProjectInitializationService(
        worktreeRepository: WorktreeRepository(
          projectsDao: database.projectsDao,
          sessionDao: database.sessionDao,
          plugin: plugin,
          gitApi: GitCliApi(
            processRunner: ProcessRunner(),
            gitPathExists: ({required String gitPath}) => false,
          ),
        ),
        filesystemRepository: FilesystemRepository(
          filesystemApi: const FilesystemApi(),
          permissionValidator: const FilesystemPermissionValidator(),
        ),
      ),
      projectActivityService: ProjectActivityService(
        projectRepository: projectRepository,
        now: () => DateTime.now().millisecondsSinceEpoch,
      ),
      healthRepository: HealthRepository(
        plugin: plugin,
        bridgeVersion: "0.0.0-test",
        filesystemAccessOk: true,
      ),
      providerRepository: ProviderRepository(plugin: plugin, projectsDao: database.projectsDao),
      agentRepository: AgentRepository(plugin: plugin, projectsDao: database.projectsDao),
      permissionRepository: permissionRepository,
      questionRepository: QuestionRepository(
        plugin: plugin,
        sessionDao: database.sessionDao,
        projectsDao: database.projectsDao,
      ),
      worktreeService: worktreeService,
      sessionEventEnrichmentService: sessionEventEnrichmentService,
      sessionMutationDispatcher: sessionTitleService,
      restartService: buildTestRestartService(),
      statusNotifier: null,
    );

    final session = orchestrator.create();
    final runFuture = session.run();

    final bridgeSocket = await relayServer.nextClient();
    final messages = bridgeSocket.asBroadcastStream();

    const connID = 8;
    bridgeSocket.add(jsonEncode(<String, Object>{"type": "phone_connected", "connId": connID}));

    final crypto = RelayCryptoService();
    final phoneKp = await crypto.generateKeyPair();
    final phonePub = await phoneKp.extractPublicKey();
    final kxMessage = RelayMessage.keyExchange(
      publicKey: base64Url.encode(phonePub.bytes).replaceAll("=", ""),
    );
    bridgeSocket.add(_withConnID(connID: connID, payload: utf8.encode(jsonEncode(kxMessage.toJson()))));

    final readyFrame = await _nextBinaryMessage(messages: messages);
    final roomKey = await _extractRoomKeyFromReady(
      framedWithConnID: readyFrame,
      phoneKp: phoneKp,
    );

    final encryptor = crypto.createSessionEncryptor(SecretKey(roomKey));
    final subscribeFrame = await frame(
      utf8.encode(jsonEncode(const RelayMessage.sseSubscribe(path: "/events").toJson())),
      encryptor: encryptor,
    );
    bridgeSocket.add(_withConnID(connID: connID, payload: subscribeFrame));

    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(pushDispatcher.events, hasLength(2));

    await session.cancel();
    await runFuture.timeout(const Duration(seconds: 5));
    await plugin.close();
    await database.close();
    await relayServer.close();
  });

  test("feeds startup and live projects summaries to the control status notifier", () async {
    final relayServer = await TestRelayServer.start();
    final database = createTestDatabase();
    final pushSubsystem = _createPushSubsystem();
    final plugin = _MutableSummaryPlugin();
    plugin.summaries = const <PluginProjectActivitySummary>[
      PluginProjectActivitySummary(
        id: "project-1",
        activeSessions: <PluginActiveSession>[PluginActiveSession(id: "session-1")],
      ),
    ];
    await _insertRootSessionBinding(
      database: database,
      pluginId: plugin.id,
      sessionId: "session-1",
      backendSessionId: "session-1",
    );
    final fakePrSyncService = _FakePrSyncService();
    final sessionRepository = SessionRepository(
      plugin: plugin,
      sessionDao: database.sessionDao,
      projectsDao: database.projectsDao,
      pullRequestDao: database.pullRequestDao,
      gitCliApi: FakeGitCliApi(),
      unseenCalculator: const SessionUnseenCalculator(),
    );
    final projectRepository = ProjectRepository(
      gitCliApi: FakeGitCliApi(),
      plugin: plugin,
      projectsDao: database.projectsDao,
      sessionDao: database.sessionDao,
      unseenCalculator: const SessionUnseenCalculator(),
      filesystemApi: FakeFilesystemApi(),
    );
    final permissionRepository = PermissionRepository(plugin: plugin, sessionDao: database.sessionDao);
    final worktreeService = WorktreeService(
      worktreeRepository: WorktreeRepository(
        projectsDao: database.projectsDao,
        sessionDao: database.sessionDao,
        gitApi: GitCliApi(
          processRunner: FakeProcessRunner(),
          gitPathExists: ({required String gitPath}) => true,
        ),
        plugin: plugin,
      ),
    );
    final relayClient = RelayClient(
      relayURL: "ws://127.0.0.1:${relayServer.port}",
      accessTokenProvider: FakeAccessTokenProvider(),
      bridgeIdProvider: FakeBridgeIdProvider(),
    );
    final sessionTitleService = SessionMutationDispatcher(sessionRepository: sessionRepository);
    final sessionEventEnrichmentService = SessionEventEnrichmentService(
      sessionRepository: sessionRepository,
      sessionMutationDispatcher: sessionTitleService,
      failureReporter: FakeFailureReporter(),
    );
    // Wired exactly like the supervised composition root: the notifier
    // observes the relay client's real connection-state stream and owns the
    // control-channel sends; the orchestrator only feeds it summaries.
    final controlClient = _RecordingControlChannelClient();
    final statusNotifier = ControlStatusNotifier(
      client: controlClient,
      pluginStatus: const Stream<PluginStatus>.empty(),
      relayConnectionState: relayClient.connectionState,
      registrations: const Stream<String>.empty(),
    );
    statusNotifier.start();

    final orchestrator = Orchestrator(
      config: BridgeConfig(
        relayURL: "ws://127.0.0.1:${relayServer.port}",
        pluginEndpoint: "http://127.0.0.1:4096",
        authBackendURL: "http://127.0.0.1:8080",
        sseReplayWindow: const Duration(minutes: 1),
        yolo: false,
      ),
      client: relayClient,
      plugin: plugin,
      sessionCreationService: SessionCreationService(
        metadataService: _FakeMetadataService(),
        worktreeService: worktreeService,
        sessionRepository: sessionRepository,
        sessionMutationDispatcher: sessionTitleService,
      ),
      pushDispatcher: pushSubsystem.dispatcher,
      completionListener: pushSubsystem.completionListener,
      maintenanceListener: pushSubsystem.maintenanceListener,
      accessTokenProvider: FakeAccessTokenProvider(),
      tokenRefresher: _FakeTokenRefresher(),
      bridgeRegistrationService: createFakeBridgeRegistrationService(),
      failureReporter: FakeFailureReporter(),
      prSyncService: fakePrSyncService,
      sessionRepository: sessionRepository,
      projectRepository: projectRepository,
      sessionUnseenService: SessionUnseenService(
        unseenRepository: SessionUnseenRepository(
          plugin: plugin,
          sessionDao: database.sessionDao,
          projectsDao: database.projectsDao,
          db: database,
          calculator: const SessionUnseenCalculator(),
        ),
        projectRepository: projectRepository,
        viewTracker: SessionViewTracker(),
      ),
      sessionViewTracker: SessionViewTracker(),
      filesystemRepository: FilesystemRepository(
        filesystemApi: const FilesystemApi(),
        permissionValidator: const FilesystemPermissionValidator(),
      ),
      gitCliApi: GitCliApi(
        processRunner: ProcessRunner(),
        gitPathExists: ({required String gitPath}) => gitPath.isNotEmpty,
      ),
      projectInitializationService: ProjectInitializationService(
        worktreeRepository: WorktreeRepository(
          projectsDao: database.projectsDao,
          sessionDao: database.sessionDao,
          plugin: plugin,
          gitApi: GitCliApi(
            processRunner: ProcessRunner(),
            gitPathExists: ({required String gitPath}) => false,
          ),
        ),
        filesystemRepository: FilesystemRepository(
          filesystemApi: const FilesystemApi(),
          permissionValidator: const FilesystemPermissionValidator(),
        ),
      ),
      projectActivityService: ProjectActivityService(
        projectRepository: projectRepository,
        now: () => DateTime.now().millisecondsSinceEpoch,
      ),
      healthRepository: HealthRepository(
        plugin: plugin,
        bridgeVersion: "0.0.0-test",
        filesystemAccessOk: true,
      ),
      providerRepository: ProviderRepository(plugin: plugin, projectsDao: database.projectsDao),
      agentRepository: AgentRepository(plugin: plugin, projectsDao: database.projectsDao),
      permissionRepository: permissionRepository,
      questionRepository: QuestionRepository(
        plugin: plugin,
        sessionDao: database.sessionDao,
        projectsDao: database.projectsDao,
      ),
      worktreeService: worktreeService,
      sessionEventEnrichmentService: sessionEventEnrichmentService,
      sessionMutationDispatcher: sessionTitleService,
      restartService: buildTestRestartService(),
      statusNotifier: statusNotifier,
    );

    final session = orchestrator.create();
    final runFuture = session.run();

    await relayServer.nextClient();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // The startup summary reaches the notifier: the last status combines the
    // live relay state (connected) with the pre-seeded active-session count.
    final startupStatuses = controlClient.sentMessages.whereType<ControlStatus>().toList();
    expect(startupStatuses, isNotEmpty);
    expect(startupStatuses.last.activeSessionCount, 1);
    expect(startupStatuses.last.relay, ControlRelayConnectionState.connected);

    // A live project-updated event re-derives the summary and pushes the
    // changed count.
    plugin.summaries = const <PluginProjectActivitySummary>[
      PluginProjectActivitySummary(
        id: "project-1",
        activeSessions: <PluginActiveSession>[
          PluginActiveSession(id: "session-1"),
          PluginActiveSession(id: "session-2"),
        ],
      ),
    ];
    plugin.emitProjectUpdated();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final statuses = controlClient.sentMessages.whereType<ControlStatus>().toList();
    expect(statuses.last.activeSessionCount, 2);

    // Deletion must rebuild the summary even when the plugin's activity
    // tracker continues to report the tombstoned backend session.
    await sessionTitleService.deleteSession(sessionId: "session-1");
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final deletionStatuses = controlClient.sentMessages.whereType<ControlStatus>().toList();
    expect(deletionStatuses.last.activeSessionCount, 1);

    await session.cancel();
    await runFuture.timeout(const Duration(seconds: 5));
    await statusNotifier.dispose();
    await plugin.close();
    await database.close();
    await relayServer.close();
  });

  test("session SSE events stay ordered while async enrichment completes", () async {
    final relayServer = await TestRelayServer.start();
    final database = createTestDatabase();
    final plugin = _EventPlugin(pendingPermissions: const []);
    final pushDispatcher = _CapturingPushDispatcher();
    final pushListeners = _createPushListeners(
      tracker: pushDispatcher.tracker,
      completionNotifier: pushDispatcher.completionNotifier,
      rateLimiter: pushDispatcher.rateLimiter,
      telemetryBuilder: pushDispatcher.telemetryBuilder,
      dispatcher: pushDispatcher,
    );
    final baseSessionRepository = SessionRepository(
      plugin: plugin,
      sessionDao: database.sessionDao,
      projectsDao: database.projectsDao,
      pullRequestDao: database.pullRequestDao,
      gitCliApi: FakeGitCliApi(),
      unseenCalculator: const SessionUnseenCalculator(),
    );
    final enrichGate = Completer<void>();
    final sessionRepository = _DelayingSessionRepository(
      base: baseSessionRepository,
      delaySessionIds: {"s1": enrichGate.future},
    );
    final projectRepository = ProjectRepository(
      gitCliApi: FakeGitCliApi(),
      plugin: plugin,
      projectsDao: database.projectsDao,
      sessionDao: database.sessionDao,
      unseenCalculator: const SessionUnseenCalculator(),
      filesystemApi: FakeFilesystemApi(),
    );
    final permissionRepository = PermissionRepository(plugin: plugin, sessionDao: database.sessionDao);
    final worktreeService = WorktreeService(
      worktreeRepository: WorktreeRepository(
        projectsDao: database.projectsDao,
        sessionDao: database.sessionDao,
        gitApi: GitCliApi(
          processRunner: FakeProcessRunner(),
          gitPathExists: ({required String gitPath}) => true,
        ),
        plugin: plugin,
      ),
    );
    final relayClient = RelayClient(
      relayURL: "ws://127.0.0.1:${relayServer.port}",
      accessTokenProvider: FakeAccessTokenProvider(),
      bridgeIdProvider: FakeBridgeIdProvider(),
    );

    await database.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
    await database.sessionDao.insertSession(
      pluginId: "opencode",
      sessionId: "s1",
      backendSessionId: "s1",
      projectId: "p1",
      isDedicated: true,
      createdAt: 10,
      worktreePath: "/tmp/worktree",
      branchName: "feature/one",
      baseBranch: null,
      baseCommit: null,

      lastAgent: null,
      lastAgentModel: null,
    );
    await database.pullRequestDao.upsertPr(
      pullRequest: const PullRequestDto(
        projectId: "p1",
        branchName: "feature/one",
        prNumber: 11,
        url: "https://github.com/org/repo/pull/11",
        title: "Newest open PR",
        state: PrState.open,
        mergeableStatus: PrMergeableStatus.mergeable,
        reviewDecision: PrReviewDecision.approved,
        checkStatus: PrCheckStatus.success,
        lastCheckedAt: 2,
        createdAt: 2,
      ),
    );

    final sessionTitleService = SessionMutationDispatcher(sessionRepository: sessionRepository);
    final sessionEventEnrichmentService = SessionEventEnrichmentService(
      sessionRepository: sessionRepository,
      sessionMutationDispatcher: sessionTitleService,
      failureReporter: FakeFailureReporter(),
    );

    final orchestrator = Orchestrator(
      config: BridgeConfig(
        relayURL: "ws://127.0.0.1:${relayServer.port}",
        pluginEndpoint: "http://127.0.0.1:4096",
        authBackendURL: "http://127.0.0.1:8080",
        sseReplayWindow: const Duration(minutes: 1),
        yolo: false,
      ),
      client: relayClient,
      plugin: plugin,
      sessionCreationService: SessionCreationService(
        metadataService: _FakeMetadataService(),
        worktreeService: worktreeService,
        sessionRepository: sessionRepository,
        sessionMutationDispatcher: sessionTitleService,
      ),
      pushDispatcher: pushDispatcher,
      completionListener: pushListeners.completionListener,
      maintenanceListener: pushListeners.maintenanceListener,
      accessTokenProvider: FakeAccessTokenProvider(),
      tokenRefresher: _FakeTokenRefresher(),
      bridgeRegistrationService: createFakeBridgeRegistrationService(),
      failureReporter: FakeFailureReporter(),
      prSyncService: _FakePrSyncService(),
      sessionRepository: sessionRepository,
      projectRepository: projectRepository,
      sessionUnseenService: SessionUnseenService(
        unseenRepository: SessionUnseenRepository(
          plugin: plugin,
          sessionDao: database.sessionDao,
          projectsDao: database.projectsDao,
          db: database,
          calculator: const SessionUnseenCalculator(),
        ),
        projectRepository: ProjectRepository(
          gitCliApi: FakeGitCliApi(),
          plugin: plugin,
          projectsDao: database.projectsDao,
          sessionDao: database.sessionDao,
          unseenCalculator: const SessionUnseenCalculator(),
          filesystemApi: FakeFilesystemApi(),
        ),
        viewTracker: SessionViewTracker(),
      ),
      sessionViewTracker: SessionViewTracker(),
      filesystemRepository: FilesystemRepository(
        filesystemApi: const FilesystemApi(),
        permissionValidator: const FilesystemPermissionValidator(),
      ),
      gitCliApi: GitCliApi(
        processRunner: ProcessRunner(),
        gitPathExists: ({required String gitPath}) => gitPath.isNotEmpty,
      ),
      projectInitializationService: ProjectInitializationService(
        worktreeRepository: WorktreeRepository(
          projectsDao: database.projectsDao,
          sessionDao: database.sessionDao,
          plugin: plugin,
          gitApi: GitCliApi(
            processRunner: ProcessRunner(),
            gitPathExists: ({required String gitPath}) => false,
          ),
        ),
        filesystemRepository: FilesystemRepository(
          filesystemApi: const FilesystemApi(),
          permissionValidator: const FilesystemPermissionValidator(),
        ),
      ),
      projectActivityService: ProjectActivityService(
        projectRepository: projectRepository,
        now: () => DateTime.now().millisecondsSinceEpoch,
      ),
      healthRepository: HealthRepository(
        plugin: plugin,
        bridgeVersion: "0.0.0-test",
        filesystemAccessOk: true,
      ),
      providerRepository: ProviderRepository(plugin: plugin, projectsDao: database.projectsDao),
      agentRepository: AgentRepository(plugin: plugin, projectsDao: database.projectsDao),
      permissionRepository: permissionRepository,
      questionRepository: QuestionRepository(
        plugin: plugin,
        sessionDao: database.sessionDao,
        projectsDao: database.projectsDao,
      ),
      worktreeService: worktreeService,
      sessionEventEnrichmentService: sessionEventEnrichmentService,
      sessionMutationDispatcher: sessionTitleService,
      restartService: buildTestRestartService(),
      statusNotifier: null,
    );

    final session = orchestrator.create();
    final runFuture = session.run();
    await plugin.waitForSubscription();
    await relayServer.nextClient();

    plugin.add(
      const BridgeSseSessionCreated(
        info: {
          "id": "s1",
          "projectID": "p1",
          "directory": "/tmp/project",
          "parentID": null,
          "title": "session",
          "time": {"created": 1, "updated": 2, "archived": null},
          "summary": null,
        },
      ),
    );
    plugin.add(const BridgeSseSessionDiff(sessionID: "s1"));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    enrichGate.complete();

    final timeoutAt = DateTime.now().add(const Duration(seconds: 2));
    while (pushDispatcher.events.length < 3) {
      if (DateTime.now().isAfter(timeoutAt)) {
        fail("Timed out waiting for mapped SSE events");
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    final emittedEvents = pushDispatcher.events.skip(1).toList(growable: false);

    expect(
      emittedEvents.map((event) => event.toJson()["type"]).toList(growable: false),
      equals(["session.created", "session.diff"]),
    );
    expect(
      ((emittedEvents.first.toJson()["info"] as Map<String, dynamic>)["pullRequest"] as Map<String, dynamic>)["number"],
      equals(11),
    );

    final summaryGate = Completer<void>();
    sessionRepository.projectSummariesDelay = summaryGate.future;
    plugin.add(const BridgeSseProjectUpdated());
    plugin.add(const BridgeSseSessionDiff(sessionID: "s1"));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      pushDispatcher.events,
      hasLength(3),
      reason: "a later plugin event must wait for the preceding summary rebuild",
    );
    summaryGate.complete();

    final summaryTimeoutAt = DateTime.now().add(const Duration(seconds: 2));
    while (pushDispatcher.events.length < 5) {
      if (DateTime.now().isAfter(summaryTimeoutAt)) {
        fail("Timed out waiting for ordered project summary events");
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(
      pushDispatcher.events.skip(3).map((event) => event.toJson()["type"]),
      equals(["projects.summary", "session.diff"]),
    );

    plugin.add(
      const BridgeSseSessionCreated(
        info: {
          "id": "opaque-session",
          "projectID": "0190f4c6-opaque-project-id",
          "directory": "/projects/native-repository",
          "parentID": null,
          "title": "opaque project session",
          "time": {"created": 3, "updated": 3, "archived": null},
          "summary": null,
        },
      ),
    );
    final persistenceTimeoutAt = DateTime.now().add(const Duration(seconds: 2));
    while (await database.projectsDao.getProject(projectId: "0190f4c6-opaque-project-id") == null) {
      if (DateTime.now().isAfter(persistenceTimeoutAt)) {
        fail("Timed out waiting for the native project placeholder");
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final nativeProject = await database.projectsDao.getProject(projectId: "0190f4c6-opaque-project-id");
    expect(nativeProject?.path, "/projects/native-repository");

    await session.cancel();
    await runFuture.timeout(const Duration(seconds: 5));
    await plugin.close();
    await database.close();
    await relayServer.close();
  });

  test("abort stream forwards session ids to push dispatcher", () async {
    final relayServer = await TestRelayServer.start();
    final database = createTestDatabase();
    final pushDispatcher = _CapturingPushDispatcher();
    final pushListeners = _createPushListeners(
      tracker: pushDispatcher.tracker,
      completionNotifier: pushDispatcher.completionNotifier,
      rateLimiter: pushDispatcher.rateLimiter,
      telemetryBuilder: pushDispatcher.telemetryBuilder,
      dispatcher: pushDispatcher,
    );
    final plugin = _AbortPlugin();
    final sessionRepository = SessionRepository(
      plugin: plugin,
      sessionDao: database.sessionDao,
      projectsDao: database.projectsDao,
      pullRequestDao: database.pullRequestDao,
      gitCliApi: FakeGitCliApi(),
      unseenCalculator: const SessionUnseenCalculator(),
    );
    final projectRepository = ProjectRepository(
      gitCliApi: FakeGitCliApi(),
      plugin: plugin,
      projectsDao: database.projectsDao,
      sessionDao: database.sessionDao,
      unseenCalculator: const SessionUnseenCalculator(),
      filesystemApi: FakeFilesystemApi(),
    );
    final permissionRepository = PermissionRepository(plugin: plugin, sessionDao: database.sessionDao);
    final worktreeService = WorktreeService(
      worktreeRepository: WorktreeRepository(
        projectsDao: database.projectsDao,
        sessionDao: database.sessionDao,
        gitApi: GitCliApi(
          processRunner: FakeProcessRunner(),
          gitPathExists: ({required String gitPath}) => true,
        ),
        plugin: plugin,
      ),
    );
    final relayClient = RelayClient(
      relayURL: "ws://127.0.0.1:${relayServer.port}",
      accessTokenProvider: FakeAccessTokenProvider(),
      bridgeIdProvider: FakeBridgeIdProvider(),
    );
    final sessionTitleService = SessionMutationDispatcher(sessionRepository: sessionRepository);
    final sessionEventEnrichmentService = SessionEventEnrichmentService(
      sessionRepository: sessionRepository,
      sessionMutationDispatcher: sessionTitleService,
      failureReporter: FakeFailureReporter(),
    );

    final orchestrator = Orchestrator(
      config: BridgeConfig(
        relayURL: "ws://127.0.0.1:${relayServer.port}",
        pluginEndpoint: "http://127.0.0.1:4096",
        authBackendURL: "http://127.0.0.1:8080",
        sseReplayWindow: const Duration(minutes: 1),
        yolo: false,
      ),
      client: relayClient,
      plugin: plugin,
      sessionCreationService: SessionCreationService(
        metadataService: _FakeMetadataService(),
        worktreeService: worktreeService,
        sessionRepository: sessionRepository,
        sessionMutationDispatcher: sessionTitleService,
      ),
      pushDispatcher: pushDispatcher,
      completionListener: pushListeners.completionListener,
      maintenanceListener: pushListeners.maintenanceListener,
      accessTokenProvider: FakeAccessTokenProvider(),
      tokenRefresher: _FakeTokenRefresher(),
      bridgeRegistrationService: createFakeBridgeRegistrationService(),
      failureReporter: FakeFailureReporter(),
      prSyncService: _FakePrSyncService(),
      sessionRepository: sessionRepository,
      projectRepository: projectRepository,
      sessionUnseenService: SessionUnseenService(
        unseenRepository: SessionUnseenRepository(
          plugin: plugin,
          sessionDao: database.sessionDao,
          projectsDao: database.projectsDao,
          db: database,
          calculator: const SessionUnseenCalculator(),
        ),
        projectRepository: ProjectRepository(
          gitCliApi: FakeGitCliApi(),
          plugin: plugin,
          projectsDao: database.projectsDao,
          sessionDao: database.sessionDao,
          unseenCalculator: const SessionUnseenCalculator(),
          filesystemApi: FakeFilesystemApi(),
        ),
        viewTracker: SessionViewTracker(),
      ),
      sessionViewTracker: SessionViewTracker(),
      filesystemRepository: FilesystemRepository(
        filesystemApi: const FilesystemApi(),
        permissionValidator: const FilesystemPermissionValidator(),
      ),
      gitCliApi: GitCliApi(
        processRunner: ProcessRunner(),
        gitPathExists: ({required String gitPath}) => gitPath.isNotEmpty,
      ),
      projectInitializationService: ProjectInitializationService(
        worktreeRepository: WorktreeRepository(
          projectsDao: database.projectsDao,
          sessionDao: database.sessionDao,
          plugin: plugin,
          gitApi: GitCliApi(
            processRunner: ProcessRunner(),
            gitPathExists: ({required String gitPath}) => false,
          ),
        ),
        filesystemRepository: FilesystemRepository(
          filesystemApi: const FilesystemApi(),
          permissionValidator: const FilesystemPermissionValidator(),
        ),
      ),
      projectActivityService: ProjectActivityService(
        projectRepository: projectRepository,
        now: () => DateTime.now().millisecondsSinceEpoch,
      ),
      healthRepository: HealthRepository(
        plugin: plugin,
        bridgeVersion: "0.0.0-test",
        filesystemAccessOk: true,
      ),
      providerRepository: ProviderRepository(plugin: plugin, projectsDao: database.projectsDao),
      agentRepository: AgentRepository(plugin: plugin, projectsDao: database.projectsDao),
      permissionRepository: permissionRepository,
      questionRepository: QuestionRepository(
        plugin: plugin,
        sessionDao: database.sessionDao,
        projectsDao: database.projectsDao,
      ),
      worktreeService: worktreeService,
      sessionEventEnrichmentService: sessionEventEnrichmentService,
      sessionMutationDispatcher: sessionTitleService,
      restartService: buildTestRestartService(),
      statusNotifier: null,
    );

    final session = orchestrator.create();
    final runFuture = session.run();
    await relayServer.nextClient();

    await _insertRootSessionBinding(
      database: database,
      pluginId: plugin.id,
      sessionId: "session-42",
      backendSessionId: "backend-session-42",
    );

    final request =
        RelayMessage.request(
              id: "abort-request",
              method: "POST",
              path: "/session/abort",
              headers: const <String, String>{},
              body: jsonEncode(const SessionIdRequest(sessionId: "session-42").toJson()),
            )
            as RelayRequest;
    final response = await session.router.route(request);

    expect(response.status, equals(200));
    expect(plugin.abortedSessionIds, equals(["backend-session-42"]));

    await session.cancel();
    await runFuture.timeout(const Duration(seconds: 5));
    await plugin.close();
    await database.close();
    await relayServer.close();
  });

  test("abort stream suppresses completion notifications end to end", () async {
    final relayServer = await TestRelayServer.start();
    final database = createTestDatabase();
    final notificationClient = _CapturingPushNotificationClient();
    final pushSubsystem = _createPushSubsystem(client: notificationClient);
    final plugin = _AbortEventPlugin();
    final sessionRepository = SessionRepository(
      plugin: plugin,
      sessionDao: database.sessionDao,
      projectsDao: database.projectsDao,
      pullRequestDao: database.pullRequestDao,
      gitCliApi: FakeGitCliApi(),
      unseenCalculator: const SessionUnseenCalculator(),
    );
    final projectRepository = ProjectRepository(
      gitCliApi: FakeGitCliApi(),
      plugin: plugin,
      projectsDao: database.projectsDao,
      sessionDao: database.sessionDao,
      unseenCalculator: const SessionUnseenCalculator(),
      filesystemApi: FakeFilesystemApi(),
    );
    final permissionRepository = PermissionRepository(plugin: plugin, sessionDao: database.sessionDao);
    final worktreeService = WorktreeService(
      worktreeRepository: WorktreeRepository(
        projectsDao: database.projectsDao,
        sessionDao: database.sessionDao,
        gitApi: GitCliApi(
          processRunner: FakeProcessRunner(),
          gitPathExists: ({required String gitPath}) => true,
        ),
        plugin: plugin,
      ),
    );
    final relayClient = RelayClient(
      relayURL: "ws://127.0.0.1:${relayServer.port}",
      accessTokenProvider: FakeAccessTokenProvider(),
      bridgeIdProvider: FakeBridgeIdProvider(),
    );
    final sessionTitleService = SessionMutationDispatcher(sessionRepository: sessionRepository);
    final sessionEventEnrichmentService = SessionEventEnrichmentService(
      sessionRepository: sessionRepository,
      sessionMutationDispatcher: sessionTitleService,
      failureReporter: FakeFailureReporter(),
    );

    final orchestrator = Orchestrator(
      config: BridgeConfig(
        relayURL: "ws://127.0.0.1:${relayServer.port}",
        pluginEndpoint: "http://127.0.0.1:4096",
        authBackendURL: "http://127.0.0.1:8080",
        sseReplayWindow: const Duration(minutes: 1),
        yolo: false,
      ),
      client: relayClient,
      plugin: plugin,
      sessionCreationService: SessionCreationService(
        metadataService: _FakeMetadataService(),
        worktreeService: worktreeService,
        sessionRepository: sessionRepository,
        sessionMutationDispatcher: sessionTitleService,
      ),
      pushDispatcher: pushSubsystem.dispatcher,
      completionListener: pushSubsystem.completionListener,
      maintenanceListener: pushSubsystem.maintenanceListener,
      accessTokenProvider: FakeAccessTokenProvider(),
      tokenRefresher: _FakeTokenRefresher(),
      bridgeRegistrationService: createFakeBridgeRegistrationService(),
      failureReporter: FakeFailureReporter(),
      prSyncService: _FakePrSyncService(),
      sessionRepository: sessionRepository,
      projectRepository: projectRepository,
      sessionUnseenService: SessionUnseenService(
        unseenRepository: SessionUnseenRepository(
          plugin: plugin,
          sessionDao: database.sessionDao,
          projectsDao: database.projectsDao,
          db: database,
          calculator: const SessionUnseenCalculator(),
        ),
        projectRepository: ProjectRepository(
          gitCliApi: FakeGitCliApi(),
          plugin: plugin,
          projectsDao: database.projectsDao,
          sessionDao: database.sessionDao,
          unseenCalculator: const SessionUnseenCalculator(),
          filesystemApi: FakeFilesystemApi(),
        ),
        viewTracker: SessionViewTracker(),
      ),
      sessionViewTracker: SessionViewTracker(),
      filesystemRepository: FilesystemRepository(
        filesystemApi: const FilesystemApi(),
        permissionValidator: const FilesystemPermissionValidator(),
      ),
      gitCliApi: GitCliApi(
        processRunner: ProcessRunner(),
        gitPathExists: ({required String gitPath}) => gitPath.isNotEmpty,
      ),
      projectInitializationService: ProjectInitializationService(
        worktreeRepository: WorktreeRepository(
          projectsDao: database.projectsDao,
          sessionDao: database.sessionDao,
          plugin: plugin,
          gitApi: GitCliApi(
            processRunner: ProcessRunner(),
            gitPathExists: ({required String gitPath}) => false,
          ),
        ),
        filesystemRepository: FilesystemRepository(
          filesystemApi: const FilesystemApi(),
          permissionValidator: const FilesystemPermissionValidator(),
        ),
      ),
      projectActivityService: ProjectActivityService(
        projectRepository: projectRepository,
        now: () => DateTime.now().millisecondsSinceEpoch,
      ),
      healthRepository: HealthRepository(
        plugin: plugin,
        bridgeVersion: "0.0.0-test",
        filesystemAccessOk: true,
      ),
      providerRepository: ProviderRepository(plugin: plugin, projectsDao: database.projectsDao),
      agentRepository: AgentRepository(plugin: plugin, projectsDao: database.projectsDao),
      permissionRepository: permissionRepository,
      questionRepository: QuestionRepository(
        plugin: plugin,
        sessionDao: database.sessionDao,
        projectsDao: database.projectsDao,
      ),
      worktreeService: worktreeService,
      sessionEventEnrichmentService: sessionEventEnrichmentService,
      sessionMutationDispatcher: sessionTitleService,
      restartService: buildTestRestartService(),
      statusNotifier: null,
    );

    final session = orchestrator.create();
    final runFuture = session.run();
    await plugin.waitForSubscription();
    await relayServer.nextClient();

    await _insertRootSessionBinding(
      database: database,
      pluginId: plugin.id,
      sessionId: "session-42",
      backendSessionId: "backend-session-42",
    );

    plugin.add(
      BridgeSseSessionStatus(
        sessionID: "session-42",
        status: const SessionStatus.busy().toJson(),
      ),
    );
    await _waitForCondition(
      check: () => pushSubsystem.tracker.wasPreviouslyBusy("session-42"),
      failureMessage: "Timed out waiting for busy status to reach push tracker",
    );

    final request =
        RelayMessage.request(
              id: "abort-request",
              method: "POST",
              path: "/session/abort",
              headers: const <String, String>{},
              body: jsonEncode(const SessionIdRequest(sessionId: "session-42").toJson()),
            )
            as RelayRequest;
    final response = await session.router.route(request);

    expect(response.status, equals(200));

    plugin.add(
      BridgeSseSessionStatus(
        sessionID: "session-42",
        status: const SessionStatus.idle().toJson(),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 700));

    expect(notificationClient.payloads, isEmpty);
    expect(plugin.abortedSessionIds, equals(["backend-session-42"]));

    await session.cancel();
    await runFuture.timeout(const Duration(seconds: 5));
    await plugin.close();
    await database.close();
    await relayServer.close();
  });

  test("slow abort still suppresses completion before abort succeeds", () async {
    final relayServer = await TestRelayServer.start();
    final database = createTestDatabase();
    final notificationClient = _CapturingPushNotificationClient();
    final pushSubsystem = _createPushSubsystem(client: notificationClient);
    final plugin = _AbortEventPlugin()
      ..abortStartedCompleter = Completer<void>()
      ..abortCompleter = Completer<void>();
    final sessionRepository = SessionRepository(
      plugin: plugin,
      sessionDao: database.sessionDao,
      projectsDao: database.projectsDao,
      pullRequestDao: database.pullRequestDao,
      gitCliApi: FakeGitCliApi(),
      unseenCalculator: const SessionUnseenCalculator(),
    );
    final projectRepository = ProjectRepository(
      gitCliApi: FakeGitCliApi(),
      plugin: plugin,
      projectsDao: database.projectsDao,
      sessionDao: database.sessionDao,
      unseenCalculator: const SessionUnseenCalculator(),
      filesystemApi: FakeFilesystemApi(),
    );
    final permissionRepository = PermissionRepository(plugin: plugin, sessionDao: database.sessionDao);
    final worktreeService = WorktreeService(
      worktreeRepository: WorktreeRepository(
        projectsDao: database.projectsDao,
        sessionDao: database.sessionDao,
        gitApi: GitCliApi(
          processRunner: FakeProcessRunner(),
          gitPathExists: ({required String gitPath}) => true,
        ),
        plugin: plugin,
      ),
    );
    final relayClient = RelayClient(
      relayURL: "ws://127.0.0.1:${relayServer.port}",
      accessTokenProvider: FakeAccessTokenProvider(),
      bridgeIdProvider: FakeBridgeIdProvider(),
    );
    final sessionTitleService = SessionMutationDispatcher(sessionRepository: sessionRepository);
    final sessionEventEnrichmentService = SessionEventEnrichmentService(
      sessionRepository: sessionRepository,
      sessionMutationDispatcher: sessionTitleService,
      failureReporter: FakeFailureReporter(),
    );

    final orchestrator = Orchestrator(
      config: BridgeConfig(
        relayURL: "ws://127.0.0.1:${relayServer.port}",
        pluginEndpoint: "http://127.0.0.1:4096",
        authBackendURL: "http://127.0.0.1:8080",
        sseReplayWindow: const Duration(minutes: 1),
        yolo: false,
      ),
      client: relayClient,
      plugin: plugin,
      sessionCreationService: SessionCreationService(
        metadataService: _FakeMetadataService(),
        worktreeService: worktreeService,
        sessionRepository: sessionRepository,
        sessionMutationDispatcher: sessionTitleService,
      ),
      pushDispatcher: pushSubsystem.dispatcher,
      completionListener: pushSubsystem.completionListener,
      maintenanceListener: pushSubsystem.maintenanceListener,
      accessTokenProvider: FakeAccessTokenProvider(),
      tokenRefresher: _FakeTokenRefresher(),
      bridgeRegistrationService: createFakeBridgeRegistrationService(),
      failureReporter: FakeFailureReporter(),
      prSyncService: _FakePrSyncService(),
      sessionRepository: sessionRepository,
      projectRepository: projectRepository,
      sessionUnseenService: SessionUnseenService(
        unseenRepository: SessionUnseenRepository(
          plugin: plugin,
          sessionDao: database.sessionDao,
          projectsDao: database.projectsDao,
          db: database,
          calculator: const SessionUnseenCalculator(),
        ),
        projectRepository: ProjectRepository(
          gitCliApi: FakeGitCliApi(),
          plugin: plugin,
          projectsDao: database.projectsDao,
          sessionDao: database.sessionDao,
          unseenCalculator: const SessionUnseenCalculator(),
          filesystemApi: FakeFilesystemApi(),
        ),
        viewTracker: SessionViewTracker(),
      ),
      sessionViewTracker: SessionViewTracker(),
      filesystemRepository: FilesystemRepository(
        filesystemApi: const FilesystemApi(),
        permissionValidator: const FilesystemPermissionValidator(),
      ),
      gitCliApi: GitCliApi(
        processRunner: ProcessRunner(),
        gitPathExists: ({required String gitPath}) => gitPath.isNotEmpty,
      ),
      projectInitializationService: ProjectInitializationService(
        worktreeRepository: WorktreeRepository(
          projectsDao: database.projectsDao,
          sessionDao: database.sessionDao,
          plugin: plugin,
          gitApi: GitCliApi(
            processRunner: ProcessRunner(),
            gitPathExists: ({required String gitPath}) => false,
          ),
        ),
        filesystemRepository: FilesystemRepository(
          filesystemApi: const FilesystemApi(),
          permissionValidator: const FilesystemPermissionValidator(),
        ),
      ),
      projectActivityService: ProjectActivityService(
        projectRepository: projectRepository,
        now: () => DateTime.now().millisecondsSinceEpoch,
      ),
      healthRepository: HealthRepository(
        plugin: plugin,
        bridgeVersion: "0.0.0-test",
        filesystemAccessOk: true,
      ),
      providerRepository: ProviderRepository(plugin: plugin, projectsDao: database.projectsDao),
      agentRepository: AgentRepository(plugin: plugin, projectsDao: database.projectsDao),
      permissionRepository: permissionRepository,
      questionRepository: QuestionRepository(
        plugin: plugin,
        sessionDao: database.sessionDao,
        projectsDao: database.projectsDao,
      ),
      worktreeService: worktreeService,
      sessionEventEnrichmentService: sessionEventEnrichmentService,
      sessionMutationDispatcher: sessionTitleService,
      restartService: buildTestRestartService(),
      statusNotifier: null,
    );

    final session = orchestrator.create();
    final runFuture = session.run();
    await plugin.waitForSubscription();
    await relayServer.nextClient();

    await _insertRootSessionBinding(
      database: database,
      pluginId: plugin.id,
      sessionId: "session-42",
      backendSessionId: "backend-session-42",
    );

    plugin.add(
      BridgeSseSessionStatus(
        sessionID: "session-42",
        status: const SessionStatus.busy().toJson(),
      ),
    );
    await _waitForCondition(
      check: () => pushSubsystem.tracker.wasPreviouslyBusy("session-42"),
      failureMessage: "Timed out waiting for busy status to reach push tracker",
    );

    final request =
        RelayMessage.request(
              id: "abort-request",
              method: "POST",
              path: "/session/abort",
              headers: const <String, String>{},
              body: jsonEncode(const SessionIdRequest(sessionId: "session-42").toJson()),
            )
            as RelayRequest;
    final responseFuture = session.router.route(request);
    await plugin.abortStartedCompleter!.future;

    plugin.add(
      BridgeSseSessionStatus(
        sessionID: "session-42",
        status: const SessionStatus.idle().toJson(),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(notificationClient.payloads, isEmpty);

    plugin.abortCompleter!.complete();
    final response = await responseFuture;

    expect(response.status, equals(200));
    expect(plugin.abortedSessionIds, equals(["backend-session-42"]));
    expect(notificationClient.payloads, isEmpty);

    await session.cancel();
    await runFuture.timeout(const Duration(seconds: 5));
    await plugin.close();
    await database.close();
    await relayServer.close();
  });
}

Future<void> _insertRootSessionBinding({
  required AppDatabase database,
  required String pluginId,
  required String sessionId,
  required String backendSessionId,
}) async {
  final projectId = "project-$sessionId";
  await database.projectsDao.insertProjectsIfMissing(projectIds: [projectId]);
  await database.sessionDao.insertSession(
    pluginId: pluginId,
    sessionId: sessionId,
    backendSessionId: backendSessionId,
    projectId: projectId,
    isDedicated: false,
    createdAt: 1,
    worktreePath: null,
    branchName: null,
    baseBranch: null,
    baseCommit: null,
    lastAgent: null,
    lastAgentModel: null,
  );
}

Future<List<int>> _nextBinaryMessage({required Stream<dynamic> messages}) async {
  final data = await messages
      .firstWhere((dynamic message) => message is List<int>)
      .timeout(
        const Duration(seconds: 2),
      );
  return List<int>.from(data as List<int>);
}

Future<bool> _waitForEventType({
  required Stream<dynamic> messages,
  required List<int> roomKey,
  required String expectedType,
}) async {
  final crypto = RelayCryptoService();
  final decryptor = crypto.createSessionEncryptor(SecretKey(List<int>.from(roomKey)));

  try {
    await for (final dynamic rawMessage in messages.timeout(const Duration(seconds: 2))) {
      if (rawMessage is! List<int>) continue;
      final framed = rawMessage.sublist(2);
      final decrypted = await unframe(framed, encryptor: decryptor);
      final message = RelayMessage.fromJson(jsonDecode(utf8.decode(decrypted)) as Map<String, dynamic>);
      if (message is! RelaySseEvent) continue;

      final decodedData = jsonDecode(message.data);
      final payload = switch (decodedData) {
        final Map<String, dynamic> dataMap => dataMap["payload"] as Map<String, dynamic>,
        _ => <String, dynamic>{},
      };
      if (payload["type"] == expectedType) return true;
    }
  } on TimeoutException {
    return false;
  }

  return false;
}

Future<List<int>> _extractRoomKeyFromReady({
  required List<int> framedWithConnID,
  required SimpleKeyPair phoneKp,
}) async {
  final payload = framedWithConnID.sublist(2);
  final bridgePublicKeyBytes = payload.sublist(0, 32);
  final encryptedFrame = payload.sublist(32);

  final crypto = RelayCryptoService();
  final bridgePublicKey = SimplePublicKey(bridgePublicKeyBytes, type: KeyPairType.x25519);
  final secret = await crypto.deriveSharedSecret(phoneKp, peerPublicKey: bridgePublicKey);
  final key = await crypto.deriveEncryptionKey(secret);
  final decryptor = crypto.createSessionEncryptor(key);
  final decrypted = await unframe(encryptedFrame, encryptor: decryptor);

  final ready = RelayMessage.fromJson(jsonDecode(utf8.decode(decrypted)) as Map<String, dynamic>);
  final relayReady = ready as RelayReady;
  return base64Url.decode(base64Url.normalize(relayReady.roomKey));
}

List<int> _withConnID({required int connID, required List<int> payload}) {
  final header = ByteData(2)..setUint16(0, connID, Endian.big);
  return <int>[header.getUint8(0), header.getUint8(1), ...payload];
}

typedef _TestPushSubsystem = ({
  PushDispatcher dispatcher,
  CompletionPushListener completionListener,
  MaintenancePushListener maintenanceListener,
  PushSessionStateTracker tracker,
});

typedef _TestPushListeners = ({
  CompletionPushListener completionListener,
  MaintenancePushListener maintenanceListener,
});

_TestPushSubsystem _createPushSubsystem({PushNotificationClient? client}) {
  final tracker = PushSessionStateTracker(now: DateTime.now);
  final completionNotifier = CompletionNotifier(tracker: tracker);
  final rateLimiter = PushRateLimiter();
  final telemetryBuilder = PushMaintenanceTelemetryBuilder(
    completionNotifier: completionNotifier,
    rateLimiter: rateLimiter,
    rssBytesReader: () => null,
  );
  final dispatcher = PushDispatcher(
    client: client ?? _NoopPushNotificationClient(),
    rateLimiter: rateLimiter,
    tracker: tracker,
    contentBuilder: const PushNotificationContentBuilder(),
  );
  final listeners = _createPushListeners(
    tracker: tracker,
    completionNotifier: completionNotifier,
    rateLimiter: rateLimiter,
    telemetryBuilder: telemetryBuilder,
    dispatcher: dispatcher,
  );
  return (
    dispatcher: dispatcher,
    completionListener: listeners.completionListener,
    maintenanceListener: listeners.maintenanceListener,
    tracker: tracker,
  );
}

_TestPushListeners _createPushListeners({
  required PushSessionStateTracker tracker,
  required CompletionNotifier completionNotifier,
  required PushRateLimiter rateLimiter,
  required PushMaintenanceTelemetryBuilder telemetryBuilder,
  required PushDispatcher dispatcher,
}) {
  return (
    completionListener: CompletionPushListener(
      tracker: tracker,
      completionNotifier: completionNotifier,
      contentBuilder: const PushNotificationContentBuilder(),
      dispatcher: dispatcher,
    ),
    maintenanceListener: MaintenancePushListener(
      tracker: tracker,
      completionNotifier: completionNotifier,
      rateLimiter: rateLimiter,
      telemetryBuilder: telemetryBuilder,
      maintenanceInterval: const Duration(minutes: 10),
    ),
  );
}

class _CapturingPushDispatcher extends PushDispatcher {
  final List<SesoriSseEvent> events = <SesoriSseEvent>[];
  final List<String> abortedSessionIds = <String>[];
  final CompletionNotifier completionNotifier;
  final PushSessionStateTracker tracker;
  final PushRateLimiter rateLimiter;
  final PushMaintenanceTelemetryBuilder telemetryBuilder;

  factory _CapturingPushDispatcher() {
    final tracker = PushSessionStateTracker(now: DateTime.now);
    final completionNotifier = CompletionNotifier(tracker: tracker);
    final rateLimiter = PushRateLimiter();
    final telemetryBuilder = PushMaintenanceTelemetryBuilder(
      completionNotifier: completionNotifier,
      rateLimiter: rateLimiter,
      rssBytesReader: () => null,
    );
    return _CapturingPushDispatcher._(
      tracker: tracker,
      completionNotifier: completionNotifier,
      rateLimiter: rateLimiter,
      telemetryBuilder: telemetryBuilder,
    );
  }

  _CapturingPushDispatcher._({
    required this.tracker,
    required this.completionNotifier,
    required this.rateLimiter,
    required this.telemetryBuilder,
  }) : super(
         tracker: tracker,
         rateLimiter: rateLimiter,
         client: _NoopPushNotificationClient(),
         contentBuilder: const PushNotificationContentBuilder(),
       );

  @override
  void dispatchImmediateIfApplicable(SesoriSseEvent event) {
    events.add(event);
  }

  @override
  Future<void> dispose() async {
    await super.dispose();
  }
}

class _AbortPlugin extends _NoopPlugin {
  final List<String> abortedSessionIds = <String>[];

  @override
  Future<void> abortSession({required String sessionId}) async {
    abortedSessionIds.add(sessionId);
  }
}

class _GatedSessionUnseenService extends SessionUnseenService {
  String? _gatedSessionId;
  Completer<void>? _started;
  Future<void>? _release;

  _GatedSessionUnseenService({
    required super.unseenRepository,
    required super.projectRepository,
    required super.viewTracker,
    super.now,
  });

  void gateSession({
    required String sessionId,
    required Completer<void> started,
    required Future<void> release,
  }) {
    _gatedSessionId = sessionId;
    _started = started;
    _release = release;
  }

  @override
  Future<void> recordSessionCreated({
    required String sessionId,
    required String projectId,
    required String sessionDirectory,
    required String? parentId,
    int? occurredAt,
  }) async {
    if (sessionId == _gatedSessionId) {
      _started?.complete();
      if (_release case final release?) await release;
    }
    await super.recordSessionCreated(
      sessionId: sessionId,
      projectId: projectId,
      sessionDirectory: sessionDirectory,
      parentId: parentId,
      occurredAt: occurredAt,
    );
  }
}

class _AbortEventPlugin extends _EventPlugin {
  final List<String> abortedSessionIds = <String>[];
  Completer<void>? abortCompleter;
  Completer<void>? abortStartedCompleter;
  Object? abortError;

  _AbortEventPlugin() : super(pendingPermissions: const []);

  @override
  Future<void> abortSession({required String sessionId}) async {
    abortedSessionIds.add(sessionId);
    abortStartedCompleter?.complete();
    if (abortError case final Object error?) {
      throw error;
    }
    if (abortCompleter case final completer?) {
      await completer.future;
    }
  }
}

class _SummaryPlugin implements NativeProjectsPluginApi {
  final void Function() onSubscribe;
  final StreamController<BridgeSseEvent> _controller = StreamController<BridgeSseEvent>.broadcast();

  _SummaryPlugin({required this.onSubscribe});

  @override
  String get id => "summary-plugin";

  @override
  bool get supportsIdentityPreservingRowlessChildSessions => false;

  @override
  Stream<BridgeSseEvent> get events {
    return Stream<BridgeSseEvent>.multi((controller) {
      onSubscribe();
      final sub = _controller.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Future<List<PluginProject>> getProjects() async => <PluginProject>[];

  @override
  Future<List<PluginSession>> getSessions(String worktree, {int? start, int? limit}) async {
    return <PluginSession>[];
  }

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<PluginSession> renameSession({required String sessionId, required String title}) async {
    throw UnimplementedError();
  }

  @override
  Future<PluginProject> renameProject({required String projectId, required String name}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteSession(String sessionId) async {}

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) async => <PluginSession>[];

  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() async => <String, PluginSessionStatus>{};

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId) async {
    return <PluginMessageWithParts>[];
  }

  @override
  Future<List<PluginCommand>> getCommands({required String? projectId}) async => <PluginCommand>[];

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
  Future<List<PluginAgent>> getAgents({required String projectId}) async => <PluginAgent>[];

  @override
  Future<List<PluginPendingPermission>> getPendingPermissions({required String sessionId}) async => [];

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({required String sessionId}) async {
    return <PluginPendingQuestion>[];
  }

  @override
  Future<List<PluginPendingQuestion>> getProjectQuestions({required String projectId}) async {
    return <PluginPendingQuestion>[];
  }

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
  Future<PluginProject> getProject(String projectId) async => const PluginProject(id: "", directory: "");

  @override
  Future<bool> healthCheck() async => true;

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() {
    return <PluginProjectActivitySummary>[
      const PluginProjectActivitySummary(
        id: "project-1",
        activeSessions: <PluginActiveSession>[
          PluginActiveSession(id: "session-1"),
        ],
      ),
    ];
  }

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) async {
    return const PluginProvidersResult(providers: <PluginProvider>[]);
  }

  @override
  Future<void> archiveSession({required String sessionId}) async {}

  @override
  Future<void> deleteWorkspace({
    required String projectId,
    required String worktreePath,
  }) async {}

  @override
  Future<void> dispose() async {}

  Future<void> close() => _controller.close();
}

/// A [_SummaryPlugin] whose active-session summary can be swapped mid-test and
/// that can emit a project-updated SSE event to trigger a live re-derivation.
class _MutableSummaryPlugin extends _SummaryPlugin {
  List<PluginProjectActivitySummary> summaries = const <PluginProjectActivitySummary>[];

  _MutableSummaryPlugin() : super(onSubscribe: () {});

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => summaries;

  void emitProjectUpdated() => _controller.add(const BridgeSseProjectUpdated());
}

/// Records the control frames the status notifier sends, decoded back into
/// [ControlMessage]s for assertions.
class _RecordingControlChannelClient implements ControlChannelClient {
  final List<String> sentFrames = <String>[];

  List<ControlMessage> get sentMessages =>
      sentFrames.map((frame) => ControlMessage.fromJson(jsonDecodeMap(frame))).toList();

  @override
  Stream<String> get inbound => const Stream<String>.empty();

  @override
  Stream<ControlChannelConnectionState> get connectionState => const Stream<ControlChannelConnectionState>.empty();

  @override
  void send(String frame) => sentFrames.add(frame);

  @override
  Future<void> connect() async {}

  @override
  Future<void> dispose() async {}
}

class _NoopPlugin implements NativeProjectsPluginApi {
  final StreamController<BridgeSseEvent> _controller = StreamController<BridgeSseEvent>.broadcast();

  @override
  String get id => "noop-plugin";

  @override
  bool get supportsIdentityPreservingRowlessChildSessions => false;

  @override
  Stream<BridgeSseEvent> get events => _controller.stream;

  Future<void> close() => _controller.close();

  @override
  Future<List<PluginProject>> getProjects() async => <PluginProject>[];

  @override
  Future<List<PluginSession>> getSessions(String projectId, {int? start, int? limit}) async {
    return <PluginSession>[];
  }

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<PluginSession> renameSession({required String sessionId, required String title}) async {
    throw UnimplementedError();
  }

  @override
  Future<PluginProject> renameProject({required String projectId, required String name}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteSession(String sessionId) async {}

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) async => <PluginSession>[];

  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() async => <String, PluginSessionStatus>{};

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId) async {
    return <PluginMessageWithParts>[];
  }

  @override
  Future<List<PluginCommand>> getCommands({required String? projectId}) async => <PluginCommand>[];

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
  Future<List<PluginAgent>> getAgents({required String projectId}) async => <PluginAgent>[];

  @override
  Future<List<PluginPendingPermission>> getPendingPermissions({required String sessionId}) async => [];

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({required String sessionId}) async {
    return <PluginPendingQuestion>[];
  }

  @override
  Future<List<PluginPendingQuestion>> getProjectQuestions({required String projectId}) async {
    return <PluginPendingQuestion>[];
  }

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
  Future<PluginProject> getProject(String projectId) async => PluginProject(id: projectId, directory: projectId);

  @override
  Future<bool> healthCheck() async => true;

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() {
    return <PluginProjectActivitySummary>[];
  }

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) async {
    return const PluginProvidersResult(providers: <PluginProvider>[]);
  }

  @override
  Future<void> archiveSession({required String sessionId}) async {}

  @override
  Future<void> deleteWorkspace({
    required String projectId,
    required String worktreePath,
  }) async {}

  @override
  Future<void> dispose() async {}
}

class _EventPlugin extends _NoopPlugin {
  int subscribeCount = 0;
  final List<String> deletedSessionIds = <String>[];
  final List<({String requestId, String sessionId, PluginPermissionReply reply})> permissionReplies = [];
  final List<PluginPendingPermission> pendingPermissions;

  _EventPlugin({required List<PluginPendingPermission> pendingPermissions})
    : pendingPermissions = List<PluginPendingPermission>.of(pendingPermissions);

  @override
  Stream<BridgeSseEvent> get events {
    return Stream<BridgeSseEvent>.multi((controller) {
      subscribeCount++;
      final sub = _controller.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = sub.cancel;
    });
  }

  void add(BridgeSseEvent event) {
    _controller.add(event);
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    deletedSessionIds.add(sessionId);
  }

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() {
    if (pendingPermissions.isEmpty) return super.getActiveSessionsSummary();
    return const [
      PluginProjectActivitySummary(
        id: "pending-project",
        activeSessions: [
          PluginActiveSession(
            id: "pending-root-session",
            mainAgentRunning: true,
            awaitingInput: true,
            childSessionIds: ["pending-child-session"],
          ),
        ],
      ),
    ];
  }

  @override
  Future<List<PluginPendingPermission>> getPendingPermissions({required String sessionId}) async {
    return pendingPermissions
        .where((permission) => (permission.displaySessionId ?? permission.sessionID) == sessionId)
        .toList();
  }

  @override
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) async {
    permissionReplies.add((requestId: requestId, sessionId: sessionId, reply: reply));
    pendingPermissions.removeWhere((permission) => permission.id == requestId);
  }

  Future<void> waitForSubscription() async {
    final timeoutAt = DateTime.now().add(const Duration(seconds: 2));
    while (subscribeCount == 0) {
      if (DateTime.now().isAfter(timeoutAt)) {
        fail("Timed out waiting for plugin event subscription");
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }
}

class _NoopPushNotificationClient extends PushNotificationClient {
  _NoopPushNotificationClient()
    : super(
        authBackendURL: "http://127.0.0.1:8080",
        tokenRefreshManager: _FakeTokenRefresher(),
        client: http.Client(),
      );

  @override
  Future<void> sendNotification(SendNotificationPayload payload) async {}
}

class _CapturingPushNotificationClient extends _NoopPushNotificationClient {
  final List<SendNotificationPayload> payloads = <SendNotificationPayload>[];

  @override
  Future<void> sendNotification(SendNotificationPayload payload) async {
    payloads.add(payload);
  }
}

Future<void> _waitForCondition({
  required bool Function() check,
  required String failureMessage,
}) async {
  final timeoutAt = DateTime.now().add(const Duration(seconds: 2));
  while (!check()) {
    if (DateTime.now().isAfter(timeoutAt)) {
      fail(failureMessage);
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _FakeMetadataService implements MetadataService {
  @override
  Future<SessionMetadata?> generate({required String firstMessage}) async => null;
}

class _FakeTokenRefresher implements TokenRefresher {
  @override
  Future<String> getAccessToken({bool forceRefresh = false}) async => "token";
}

class _FakePrSyncService extends PrSyncService {
  final StreamController<String> _controller = StreamController<String>.broadcast();

  _FakePrSyncService()
    : super(
        prSource: _NoopPrSource(),
        pullRequestRepository: _NoopPullRequestRepository(),
        sessionRepository: _NoopSessionRepository(),
        clock: const Clock(),
      );

  @override
  Stream<String> get prChanges => _controller.stream;

  void emitProjectChange({required String projectId}) {
    _controller.add(projectId);
  }

  @override
  Future<void> triggerRefresh({required String projectId, required String projectPath}) async {}

  @override
  void dispose() {
    _controller.close();
  }
}

class _NoopPrSource implements PrSourceRepository {
  @override
  Future<bool> isGithubCliAvailable() async => false;
  @override
  Future<bool> isGithubCliAuthenticated() async => false;
  @override
  Future<bool> hasGitHubRemote({required String projectPath}) async => false;
  @override
  Future<List<GhPullRequest>> listOpenPrs({required String workingDirectory}) async => const <GhPullRequest>[];
  @override
  Future<GhPullRequest> getPrByNumber({required int number, required String workingDirectory}) async {
    throw StateError("getPrByNumber should not be called");
  }
}

class _NoopPullRequestRepository implements PullRequestRepository {
  @override
  Future<List<PullRequestDto>> getActivePullRequestsByProjectId({required String projectId}) async =>
      const <PullRequestDto>[];

  @override
  Future<Map<String, List<PullRequestDto>>> getPrsBySessionIds({required List<String> sessionIds}) async {
    return <String, List<PullRequestDto>>{};
  }

  @override
  bool hasChangedFromExisting({required PullRequestDto? existing, required GhPullRequest pr}) => true;

  @override
  Future<void> upsertFromGhPr({
    required String projectId,
    required GhPullRequest pr,
    required int createdAt,
    required int lastCheckedAt,
  }) async {}

  @override
  Future<void> deletePr({required String projectId, required int prNumber}) async {}

  @override
  Future<void> upsertPullRequest({required PullRequestDto record}) async {}
}

Session _deletedSession(String sessionId) => Session(
  branchName: null,
  id: sessionId,
  pluginId: "fake",
  projectID: "",
  directory: "",
  parentID: null,
  title: null,
  time: null,
  pullRequest: null,
  promptDefaults: null,
);

class _NoopSessionRepository implements SessionRepository {
  @override
  bool get sessionListIsAuthoritative => true;

  @override
  Future<bool> setSessionTitleIfStored({required String sessionId, required String? title}) async => true;

  @override
  Future<Session> deleteSession({required String sessionId}) async => _deletedSession(sessionId);

  @override
  Future<bool> isSessionTombstoned({required String sessionId}) async => false;

  @override
  Future<List<MessageWithParts>> getSessionMessages({required String sessionId}) async => const [];

  @override
  Future<List<ProjectActivitySummary>> getProjectActivitySummaries() async => const [];

  @override
  Future<Session> createSession({
    required String pluginId,
    required String directory,
    required String? parentSessionId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required String? agent,
    required PromptModel? model,
  }) async => const Session(
    branchName: null,
    id: "",
    pluginId: "fake",
    projectID: "",
    directory: "",
    parentID: null,
    title: null,
    time: null,
    pullRequest: null,
    promptDefaults: null,
  );
  @override
  Future<List<Session>> getSessionsForProject({
    required String projectId,
    required int? start,
    required int? limit,
  }) async => const <Session>[];
  @override
  Future<Session> enrichSession({required Session session}) async => session;
  @override
  Future<Session> enrichPluginSession({required PluginSession pluginSession}) async =>
      pluginSession.toSharedSession(pluginId: "fake");
  @override
  Future<Session> enrichPluginEventSessionJson({required Map<String, dynamic> sessionJson}) async =>
      Session.fromJson(sessionJson);
  @override
  Future<List<Session>> enrichSessions({required List<Session> sessions}) async => sessions;
  @override
  Future<List<Session>> getChildSessions({required String sessionId}) async => const <Session>[];
  @override
  Future<List<StoredSession>> getStoredSessionsByProjectId({required String projectId}) async =>
      const <StoredSession>[];
  @override
  Future<bool> hasOtherActiveSessionsSharing({
    required String sessionId,
    required String projectId,
    required String? worktreePath,
    required String? branchName,
  }) async => false;
  @override
  Future<String?> getProjectPath({required String projectId}) async => null;
  @override
  Future<StoredSession?> getStoredSession({required String sessionId}) async => null;

  @override
  Future<StoredSession> requireActiveStoredSession({
    required String sessionId,
    required SessionOperation operation,
  }) async {
    throw PluginOperationException.notFound(
      operation.name,
      message: "session $sessionId was not found",
    );
  }

  @override
  Future<Session?> getCatalogSession({required String sessionId}) async => null;

  @override
  Future<SessionStatusResponse> getSessionStatuses() async => const SessionStatusResponse(statuses: {});

  @override
  void ensurePluginAvailable({required String pluginId, required SessionOperation operation}) {}

  @override
  Future<void> archiveStoredSession({
    required String sessionId,
    required int archivedAt,
  }) async {}

  @override
  Future<void> unarchiveStoredSession({required String sessionId}) async {}

  @override
  Future<void> insertStoredSession({
    required String sessionId,
    required String backendSessionId,
    required String pluginId,
    required String projectId,
    required bool isDedicated,
    required int createdAt,
    required String? worktreePath,
    required String? branchName,
    required String? baseBranch,
    required String? baseCommit,
    required String? agent,
    required AgentModel? agentModel,
  }) async {}

  @override
  Future<void> updatePromptDefaults({
    required String sessionId,
    required String? agent,
    required AgentModel? agentModel,
  }) async {}

  @override
  Future<String?> findProjectIdForSession({required String sessionId}) async => null;
  @override
  Future<Session?> getSessionForProject({required String projectId, required String sessionId}) async => null;

  @override
  Future<void> abortSession({required String sessionId}) async {}

  @override
  Future<void> notifySessionArchived({required String sessionId}) async {}

  @override
  Future<void> sendCommand({
    required String sessionId,
    required String command,
    required String arguments,
    required SessionVariant? variant,
    required String? agent,
    required PromptModel? model,
  }) async {}

  @override
  Future<CommandListResponse> getCommands({required String? projectId, required String pluginId}) async =>
      const CommandListResponse(items: []);

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required String? agent,
    required PromptModel? model,
  }) async {}

  @override
  Future<Session> renameSession({required String sessionId, required String title}) async => const Session(
    branchName: null,
    id: "",
    pluginId: "fake",
    projectID: "",
    directory: "",
    parentID: null,
    title: null,
    time: null,
    pullRequest: null,
    promptDefaults: null,
  );

  @override
  Future<String> resolveProjectDirectory({required String projectId}) async => projectId;
}

class _DelayingSessionRepository implements SessionRepository {
  @override
  bool get sessionListIsAuthoritative => true;

  @override
  Future<bool> setSessionTitleIfStored({required String sessionId, required String? title}) =>
      _base.setSessionTitleIfStored(sessionId: sessionId, title: title);

  @override
  Future<Session> deleteSession({required String sessionId}) => _base.deleteSession(sessionId: sessionId);

  @override
  Future<bool> isSessionTombstoned({required String sessionId}) => _base.isSessionTombstoned(sessionId: sessionId);

  @override
  Future<List<MessageWithParts>> getSessionMessages({required String sessionId}) =>
      _base.getSessionMessages(sessionId: sessionId);

  @override
  Future<List<ProjectActivitySummary>> getProjectActivitySummaries() async {
    final delay = projectSummariesDelay;
    if (delay != null) await delay;
    return _base.getProjectActivitySummaries();
  }

  final SessionRepository _base;
  final Map<String, Future<void>> _delaySessionIds;
  Future<void>? projectSummariesDelay;

  _DelayingSessionRepository({
    required SessionRepository base,
    required Map<String, Future<void>> delaySessionIds,
  }) : _base = base,
       _delaySessionIds = delaySessionIds;

  @override
  Future<Session> enrichSession({required Session session}) async {
    final delay = _delaySessionIds[session.id];
    if (delay != null) {
      await delay;
    }
    return _base.enrichSession(session: session);
  }

  @override
  Future<Session> createSession({
    required String pluginId,
    required String directory,
    required String? parentSessionId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required String? agent,
    required PromptModel? model,
  }) {
    return _base.createSession(
      pluginId: pluginId,
      directory: directory,
      parentSessionId: parentSessionId,
      parts: parts,
      variant: variant,
      agent: agent,
      model: model,
    );
  }

  @override
  Future<void> sendCommand({
    required String sessionId,
    required String command,
    required String arguments,
    required SessionVariant? variant,
    required String? agent,
    required PromptModel? model,
  }) async {
    return _base.sendCommand(
      sessionId: sessionId,
      command: command,
      arguments: arguments,
      variant: variant,
      agent: agent,
      model: model,
    );
  }

  @override
  Future<CommandListResponse> getCommands({required String? projectId, required String pluginId}) {
    return _base.getCommands(projectId: projectId, pluginId: pluginId);
  }

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required List<PromptPart> parts,
    required SessionVariant? variant,
    required String? agent,
    required PromptModel? model,
  }) async {
    return _base.sendPrompt(sessionId: sessionId, parts: parts, variant: variant, agent: agent, model: model);
  }

  @override
  Future<Session> enrichPluginSession({required PluginSession pluginSession}) async {
    return enrichSession(session: pluginSession.toSharedSession(pluginId: "fake"));
  }

  @override
  Future<Session> enrichPluginEventSessionJson({required Map<String, dynamic> sessionJson}) async {
    return enrichSession(session: Session.fromJson(sessionJson));
  }

  @override
  Future<List<Session>> enrichSessions({required List<Session> sessions}) async {
    return _base.enrichSessions(sessions: sessions);
  }

  @override
  Future<List<Session>> getSessionsForProject({
    required String projectId,
    required int? start,
    required int? limit,
  }) async {
    return _base.getSessionsForProject(projectId: projectId, start: start, limit: limit);
  }

  @override
  Future<List<Session>> getChildSessions({required String sessionId}) async {
    return _base.getChildSessions(sessionId: sessionId);
  }

  @override
  Future<List<StoredSession>> getStoredSessionsByProjectId({required String projectId}) async {
    return _base.getStoredSessionsByProjectId(projectId: projectId);
  }

  @override
  Future<bool> hasOtherActiveSessionsSharing({
    required String sessionId,
    required String projectId,
    required String? worktreePath,
    required String? branchName,
  }) async {
    return _base.hasOtherActiveSessionsSharing(
      sessionId: sessionId,
      projectId: projectId,
      worktreePath: worktreePath,
      branchName: branchName,
    );
  }

  @override
  Future<String?> getProjectPath({required String projectId}) async {
    return _base.getProjectPath(projectId: projectId);
  }

  @override
  Future<StoredSession?> getStoredSession({required String sessionId}) async {
    return _base.getStoredSession(sessionId: sessionId);
  }

  @override
  Future<StoredSession> requireActiveStoredSession({
    required String sessionId,
    required SessionOperation operation,
  }) {
    return _base.requireActiveStoredSession(sessionId: sessionId, operation: operation);
  }

  @override
  Future<Session?> getCatalogSession({required String sessionId}) {
    return _base.getCatalogSession(sessionId: sessionId);
  }

  @override
  Future<SessionStatusResponse> getSessionStatuses() {
    return _base.getSessionStatuses();
  }

  @override
  void ensurePluginAvailable({required String pluginId, required SessionOperation operation}) {
    _base.ensurePluginAvailable(pluginId: pluginId, operation: operation);
  }

  @override
  Future<void> archiveStoredSession({
    required String sessionId,
    required int archivedAt,
  }) {
    return _base.archiveStoredSession(sessionId: sessionId, archivedAt: archivedAt);
  }

  @override
  Future<void> unarchiveStoredSession({required String sessionId}) {
    return _base.unarchiveStoredSession(sessionId: sessionId);
  }

  @override
  Future<void> insertStoredSession({
    required String sessionId,
    required String backendSessionId,
    required String pluginId,
    required String projectId,
    required bool isDedicated,
    required int createdAt,
    required String? worktreePath,
    required String? branchName,
    required String? baseBranch,
    required String? baseCommit,
    required String? agent,
    required AgentModel? agentModel,
  }) {
    return _base.insertStoredSession(
      sessionId: sessionId,
      backendSessionId: backendSessionId,
      pluginId: pluginId,
      projectId: projectId,
      isDedicated: isDedicated,
      createdAt: createdAt,
      worktreePath: worktreePath,
      branchName: branchName,
      baseBranch: baseBranch,
      baseCommit: baseCommit,
      agent: agent,
      agentModel: agentModel,
    );
  }

  @override
  Future<void> updatePromptDefaults({
    required String sessionId,
    required String? agent,
    required AgentModel? agentModel,
  }) {
    return _base.updatePromptDefaults(
      sessionId: sessionId,
      agent: agent,
      agentModel: agentModel,
    );
  }

  @override
  Future<String?> findProjectIdForSession({required String sessionId}) {
    return _base.findProjectIdForSession(sessionId: sessionId);
  }

  @override
  Future<Session?> getSessionForProject({required String projectId, required String sessionId}) {
    return _base.getSessionForProject(projectId: projectId, sessionId: sessionId);
  }

  @override
  Future<void> abortSession({required String sessionId}) {
    return _base.abortSession(sessionId: sessionId);
  }

  @override
  Future<void> notifySessionArchived({required String sessionId}) {
    return _base.notifySessionArchived(sessionId: sessionId);
  }

  @override
  Future<Session> renameSession({required String sessionId, required String title}) {
    return _base.renameSession(sessionId: sessionId, title: title);
  }

  @override
  Future<String> resolveProjectDirectory({required String projectId}) =>
      _base.resolveProjectDirectory(projectId: projectId);
}
