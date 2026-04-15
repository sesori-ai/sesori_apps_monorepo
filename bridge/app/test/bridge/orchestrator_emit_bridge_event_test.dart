import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:cryptography/cryptography.dart";
import "package:sesori_bridge/src/auth/token_refresher.dart";
import "package:sesori_bridge/src/bridge/api/database/tables/pull_requests_table.dart";
import "package:sesori_bridge/src/bridge/api/gh_pull_request.dart";
import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/metadata_service.dart";
import "package:sesori_bridge/src/bridge/models/bridge_config.dart";
import "package:sesori_bridge/src/bridge/models/session_metadata.dart";
import "package:sesori_bridge/src/bridge/orchestrator.dart";
import "package:sesori_bridge/src/bridge/persistence/tables/session_table.dart";
import "package:sesori_bridge/src/bridge/relay_client.dart";
import "package:sesori_bridge/src/bridge/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/bridge/repositories/permission_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/pr_source_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/project_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/worktree_repository.dart";
import "package:sesori_bridge/src/bridge/services/pr_sync_service.dart";
import "package:sesori_bridge/src/bridge/services/session_event_enrichment_service.dart";
import "package:sesori_bridge/src/bridge/services/session_persistence_service.dart";
import "package:sesori_bridge/src/bridge/services/worktree_service.dart";
import "package:sesori_bridge/src/push/completion_notifier.dart";
import "package:sesori_bridge/src/push/push_notification_client.dart";
import "package:sesori_bridge/src/push/push_notification_service.dart";
import "package:sesori_bridge/src/push/push_rate_limiter.dart";
import "package:sesori_bridge/src/push/push_session_state_tracker.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" hide PermissionReply;
import "package:test/test.dart";

import "../helpers/test_database.dart";
import "../helpers/test_helpers.dart";
import "routing/get_session_diffs_handler_test_helpers.dart";

void main() {
  test("pr sync stream enqueues sessions.updated SSE event for subscribers", () async {
    final relayServer = await TestRelayServer.start();
    final database = createTestDatabase();
    final plugin = _NoopPlugin();
    final fakePrSyncService = _FakePrSyncService();
    final pullRequestRepository = PullRequestRepository(
      pullRequestDao: database.pullRequestDao,
      projectsDao: database.projectsDao,
    );
    final sessionRepository = SessionRepository(
      plugin: plugin,
      sessionDao: database.sessionDao,
      pullRequestRepository: pullRequestRepository,
    );
    final projectRepository = ProjectRepository(
      plugin: plugin,
      projectsDao: database.projectsDao,
    );
    final permissionRepository = PermissionRepository(plugin: plugin);
    final sessionPersistenceService = SessionPersistenceService(
      projectsDao: database.projectsDao,
      sessionDao: database.sessionDao,
      db: database,
    );
    final worktreeService = WorktreeService(
      worktreeRepository: WorktreeRepository(
        projectsDao: database.projectsDao,
        sessionDao: database.sessionDao,
        gitApi: GitCliApi(
          processRunner: FakeProcessRunner(),
          gitPathExists: ({required String gitPath}) => true,
        ),
      ),
    );
    final relayClient = RelayClient(
      relayURL: "ws://127.0.0.1:${relayServer.port}",
      accessTokenProvider: FakeAccessTokenProvider(""),
    );
    final sessionEventEnrichmentService = SessionEventEnrichmentService(
      sessionRepository: sessionRepository,
    );

    final orchestrator = Orchestrator(
      config: BridgeConfig(
        relayURL: "ws://127.0.0.1:${relayServer.port}",
        serverURL: "http://127.0.0.1:4096",
        serverPassword: null,
        authBackendURL: "http://127.0.0.1:8080",
        sseReplayWindow: const Duration(minutes: 1),
      ),
      client: relayClient,
      plugin: plugin,
      metadataService: _FakeMetadataService(),
      pushNotificationService: _createPushNotificationService(),
      tokenRefresher: _FakeTokenRefresher(),
      failureReporter: FakeFailureReporter(),
      prSyncService: fakePrSyncService,
      sessionRepository: sessionRepository,
      projectRepository: projectRepository,
      permissionRepository: permissionRepository,
      sessionPersistenceService: sessionPersistenceService,
      worktreeService: worktreeService,
      sessionEventEnrichmentService: sessionEventEnrichmentService,
    );

    final session = orchestrator.create();
    final runFuture = session.run();

    final bridgeSocket = await relayServer.nextClient();
    final messages = bridgeSocket.asBroadcastStream();

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
    final subscribeFrame = await frame(
      utf8.encode(jsonEncode(const RelayMessage.sseSubscribe(path: "/events").toJson())),
      encryptor: encryptor,
    );
    bridgeSocket.add(_withConnID(connID: connID, payload: subscribeFrame));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    fakePrSyncService.emitProjectChange(projectId: "project-123");

    final found = await _waitForEventType(
      messages: messages,
      roomKey: roomKey,
      expectedType: "sessions.updated",
    );
    expect(found, isTrue);

    await session.cancel();
    await runFuture.timeout(const Duration(seconds: 5));
    await plugin.close();
    await database.close();
    await relayServer.close();
  });

  test("pre-seeds and forwards projects summary to push service", () async {
    final relayServer = await TestRelayServer.start();
    final database = createTestDatabase();
    final pushService = _CapturingPushNotificationService();
    final plugin = _SummaryPlugin(
      onSubscribe: () {
        expect(pushService.events.length, 1);
      },
    );
    final fakePrSyncService = _FakePrSyncService();
    final pullRequestRepository = PullRequestRepository(
      pullRequestDao: database.pullRequestDao,
      projectsDao: database.projectsDao,
    );
    final sessionRepository = SessionRepository(
      plugin: plugin,
      sessionDao: database.sessionDao,
      pullRequestRepository: pullRequestRepository,
    );
    final relayClient = RelayClient(
      relayURL: "ws://127.0.0.1:${relayServer.port}",
      accessTokenProvider: FakeAccessTokenProvider(""),
    );
    final sessionEventEnrichmentService = SessionEventEnrichmentService(
      sessionRepository: sessionRepository,
    );
    final projectRepository = ProjectRepository(plugin: plugin, projectsDao: database.projectsDao);
    final permissionRepository = PermissionRepository(plugin: plugin);
    final sessionPersistenceService = SessionPersistenceService(
      projectsDao: database.projectsDao,
      sessionDao: database.sessionDao,
      db: database,
    );
    final worktreeService = WorktreeService(
      worktreeRepository: WorktreeRepository(
        projectsDao: database.projectsDao,
        sessionDao: database.sessionDao,
        gitApi: GitCliApi(
          processRunner: FakeProcessRunner(),
          gitPathExists: ({required String gitPath}) => true,
        ),
      ),
    );

    final orchestrator = Orchestrator(
      config: BridgeConfig(
        relayURL: "ws://127.0.0.1:${relayServer.port}",
        serverURL: "http://127.0.0.1:4096",
        serverPassword: null,
        authBackendURL: "http://127.0.0.1:8080",
        sseReplayWindow: const Duration(minutes: 1),
      ),
      client: relayClient,
      plugin: plugin,
      metadataService: _FakeMetadataService(),
      pushNotificationService: pushService,
      tokenRefresher: _FakeTokenRefresher(),
      failureReporter: FakeFailureReporter(),
      prSyncService: fakePrSyncService,
      sessionRepository: sessionRepository,
      projectRepository: projectRepository,
      permissionRepository: permissionRepository,
      sessionPersistenceService: sessionPersistenceService,
      worktreeService: worktreeService,
      sessionEventEnrichmentService: sessionEventEnrichmentService,
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

    expect(pushService.events, hasLength(2));

    await session.cancel();
    await runFuture.timeout(const Duration(seconds: 5));
    await plugin.close();
    await database.close();
    await relayServer.close();
  });

  test("session SSE events stay ordered while async enrichment completes", () async {
    final relayServer = await TestRelayServer.start();
    final database = createTestDatabase();
    final plugin = _EventPlugin();
    final pullRequestRepository = PullRequestRepository(
      pullRequestDao: database.pullRequestDao,
      projectsDao: database.projectsDao,
    );
    final baseSessionRepository = SessionRepository(
      plugin: plugin,
      sessionDao: database.sessionDao,
      pullRequestRepository: pullRequestRepository,
    );
    final enrichGate = Completer<void>();
    final sessionRepository = _DelayingSessionRepository(
      base: baseSessionRepository,
      delaySessionIds: {"s1": enrichGate.future},
    );
    final projectRepository = ProjectRepository(
      plugin: plugin,
      projectsDao: database.projectsDao,
    );
    final permissionRepository = PermissionRepository(plugin: plugin);
    final sessionPersistenceService = SessionPersistenceService(
      projectsDao: database.projectsDao,
      sessionDao: database.sessionDao,
      db: database,
    );
    final worktreeService = WorktreeService(
      worktreeRepository: WorktreeRepository(
        projectsDao: database.projectsDao,
        sessionDao: database.sessionDao,
        gitApi: GitCliApi(
          processRunner: FakeProcessRunner(),
          gitPathExists: ({required String gitPath}) => true,
        ),
      ),
    );
    final relayClient = RelayClient(
      relayURL: "ws://127.0.0.1:${relayServer.port}",
      accessTokenProvider: FakeAccessTokenProvider(""),
    );

    await database.projectsDao.insertProjectsIfMissing(projectIds: ["p1"]);
    await database.sessionDao.insertSession(
      sessionId: "s1",
      projectId: "p1",
      isDedicated: true,
      createdAt: 10,
      worktreePath: "/tmp/worktree",
      branchName: "feature/one",
      baseBranch: null,
      baseCommit: null,
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

    final pushService = _CapturingPushNotificationService();
    final sessionEventEnrichmentService = SessionEventEnrichmentService(
      sessionRepository: sessionRepository,
    );

    final orchestrator = Orchestrator(
      config: BridgeConfig(
        relayURL: "ws://127.0.0.1:${relayServer.port}",
        serverURL: "http://127.0.0.1:4096",
        serverPassword: null,
        authBackendURL: "http://127.0.0.1:8080",
        sseReplayWindow: const Duration(minutes: 1),
      ),
      client: relayClient,
      plugin: plugin,
      metadataService: _FakeMetadataService(),
      pushNotificationService: pushService,
      tokenRefresher: _FakeTokenRefresher(),
      failureReporter: FakeFailureReporter(),
      prSyncService: _FakePrSyncService(),
      sessionRepository: sessionRepository,
      projectRepository: projectRepository,
      permissionRepository: permissionRepository,
      sessionPersistenceService: sessionPersistenceService,
      worktreeService: worktreeService,
      sessionEventEnrichmentService: sessionEventEnrichmentService,
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
    while (pushService.events.length < 3) {
      if (DateTime.now().isAfter(timeoutAt)) {
        fail("Timed out waiting for mapped SSE events");
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    final emittedEvents = pushService.events.skip(1).toList(growable: false);

    expect(
      emittedEvents.map((event) => event.toJson()["type"]).toList(growable: false),
      equals(["session.created", "session.diff"]),
    );
    expect(
      ((emittedEvents.first.toJson()["info"] as Map<String, dynamic>)["pullRequest"] as Map<String, dynamic>)["number"],
      equals(11),
    );

    await session.cancel();
    await runFuture.timeout(const Duration(seconds: 5));
    await plugin.close();
    await database.close();
    await relayServer.close();
  });
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

  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (DateTime.now().isBefore(deadline)) {
    List<int> framedWithConnID;
    try {
      framedWithConnID = await _nextBinaryMessage(messages: messages);
    } on TimeoutException {
      return false;
    }
    final framed = framedWithConnID.sublist(2);
    final decrypted = await unframe(framed, encryptor: decryptor);
    final message = RelayMessage.fromJson(jsonDecode(utf8.decode(decrypted)) as Map<String, dynamic>);
    if (message is! RelaySseEvent) {
      continue;
    }

    final decodedData = jsonDecode(message.data);
    final payload = switch (decodedData) {
      final Map<String, dynamic> dataMap => dataMap["payload"] as Map<String, dynamic>,
      _ => <String, dynamic>{},
    };
    if (payload["type"] == expectedType) {
      return true;
    }
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

PushNotificationService _createPushNotificationService() {
  final tracker = PushSessionStateTracker();
  final completionNotifier = CompletionNotifier(tracker: tracker);
  return PushNotificationService(
    client: _NoopPushNotificationClient(),
    rateLimiter: PushRateLimiter(),
    tracker: tracker,
    completionNotifier: completionNotifier,
  );
}

class _CapturingPushNotificationService extends PushNotificationService {
  final List<SesoriSseEvent> events = <SesoriSseEvent>[];

  _CapturingPushNotificationService()
    : this._(
        tracker: PushSessionStateTracker(),
      );

  _CapturingPushNotificationService._({required super.tracker})
    : super(
        client: _NoopPushNotificationClient(),
        rateLimiter: PushRateLimiter(),
        completionNotifier: CompletionNotifier(tracker: tracker),
      );

  @override
  void handleSseEvent(SesoriSseEvent event) {
    events.add(event);
  }

  @override
  Future<void> dispose() async {}
}

class _SummaryPlugin implements BridgePlugin {
  final void Function() onSubscribe;
  final StreamController<BridgeSseEvent> _controller = StreamController<BridgeSseEvent>.broadcast();

  _SummaryPlugin({required this.onSubscribe});

  @override
  String get id => "summary-plugin";

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
  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {}

  @override
  Future<void> abortSession({required String sessionId}) async {}

  @override
  Future<List<PluginAgent>> getAgents() async => <PluginAgent>[];

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
  Future<void> rejectQuestion(String questionId) async {}

  @override
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) async {}

  @override
  Future<PluginProject> getProject(String projectId) async => const PluginProject(id: "");

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
  Future<PluginProvidersResult> getProviders({required bool connectedOnly}) async {
    return const PluginProvidersResult(providers: <PluginProvider>[]);
  }

  @override
  Future<void> archiveSession({required String sessionId}) async {}

  @override
  Future<void> dispose() async {}

  Future<void> close() => _controller.close();
}

class _NoopPlugin implements BridgePlugin {
  final StreamController<BridgeSseEvent> _controller = StreamController<BridgeSseEvent>.broadcast();

  @override
  String get id => "noop-plugin";

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
  Future<void> sendPrompt({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {}

  @override
  Future<void> abortSession({required String sessionId}) async {}

  @override
  Future<List<PluginAgent>> getAgents() async => <PluginAgent>[];

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
  Future<void> rejectQuestion(String questionId) async {}

  @override
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) async {}

  @override
  Future<PluginProject> getProject(String projectId) async => const PluginProject(id: "");

  @override
  Future<bool> healthCheck() async => true;

  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() {
    return <PluginProjectActivitySummary>[];
  }

  @override
  Future<PluginProvidersResult> getProviders({required bool connectedOnly}) async {
    return const PluginProvidersResult(providers: <PluginProvider>[]);
  }

  @override
  Future<void> archiveSession({required String sessionId}) async {}

  @override
  Future<void> dispose() async {}
}

class _EventPlugin extends _NoopPlugin {
  int subscribeCount = 0;

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
      );

  @override
  Future<void> sendNotification(SendNotificationPayload payload) async {}
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

class _NoopSessionRepository implements SessionRepository {
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
      Session.fromJson(pluginSession.toJson());
  @override
  Future<Session> enrichSessionJson({required Map<String, dynamic> sessionJson}) async => Session.fromJson(sessionJson);
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
  Future<SessionDto?> getStoredSession({required String sessionId}) async => null;
}

class _DelayingSessionRepository implements SessionRepository {
  final SessionRepository _base;
  final Map<String, Future<void>> _delaySessionIds;

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
  Future<Session> enrichPluginSession({required PluginSession pluginSession}) async {
    return enrichSession(session: Session.fromJson(pluginSession.toJson()));
  }

  @override
  Future<Session> enrichSessionJson({required Map<String, dynamic> sessionJson}) async {
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
  Future<SessionDto?> getStoredSession({required String sessionId}) async {
    return _base.getStoredSession(sessionId: sessionId);
  }
}
