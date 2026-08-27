import "dart:async";
import "dart:io";

import "package:http/http.dart" as http;
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/foundation/process_runner.dart";
import "package:sesori_bridge/src/foundation/relay_client.dart";
import "package:sesori_bridge/src/models/bridge_config.dart";
import "package:sesori_bridge/src/orchestrator.dart";
import "package:sesori_bridge/src/repositories/plugin_lifecycle_repository.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/plugin_lifecycle_test_support.dart";
import "../helpers/plugin_runtime_test_support.dart";
import "../helpers/restart_test_support.dart";
import "../helpers/test_chat_history.dart";
import "../helpers/test_database.dart";
import "../helpers/test_helpers.dart";
import "routing/routing_test_helpers.dart";

void main() {
  test("zero-plugin composition becomes ready without an inbound relay frame", () async {
    final relayServer = await TestRelayServer.start();
    final database = createTestDatabase();
    final pluginRuntime = createRegisteredTestPluginRuntime(pluginIds: const ["opencode"]);
    final bridgeSettingsRepository = createTestBridgeSettingsRepository();
    final lifecycleService =
        PluginLifecycleService(
          lifecycleRepository: PluginLifecycleRepository(runtime: pluginRuntime),
          preferredDefaultPluginId: legacyMissingPluginId,
          bridgeSettingsRepository: bridgeSettingsRepository,
          idleTimerScheduler: const PluginIdleTimerScheduler(),
          bridgeIdProvider: FakeBridgeIdProvider("br_test1234"),
          plugins: const [
            (
              id: "opencode",
              displayName: "OpenCode",
              activationPolicy: PluginActivationPolicy.onDemand,
              residencyPolicy: PluginResidencyPolicy.transient,
              sessionOptionsScope: PluginSessionOptionsScope.project,
              managementCapabilities: defaultManagementCapabilities,
              supportsPromptAttachments: false,
            ),
          ],
        )..initialize(
          disabledPluginIds: const {"opencode"},
          setupById: const {
            "opencode": PluginSetupNotInspected(),
          },
        );
    final httpClient = http.Client();
    final relayClient = RelayClient(
      relayURL: "ws://127.0.0.1:${relayServer.port}",
      accessTokenProvider: FakeAccessTokenProvider(""),
      bridgeIdProvider: FakeBridgeIdProvider(),
    );
    final testChatHistory = createTestChatHistory();
    final composition = Orchestrator(
      config: BridgeConfig(
        relayURL: "ws://127.0.0.1:${relayServer.port}",
        authBackendURL: "http://127.0.0.1:8080",
        sseReplayWindow: const Duration(minutes: 1),
        yolo: false,
      ),
      client: relayClient,
      pluginLifecycleService: lifecycleService,
      pluginRuntime: pluginRuntime,
      bridgeSettingsRepository: bridgeSettingsRepository,
      clock: const ServerClock(),
      database: database,
      chatHistoryDatabase: testChatHistory.database,
      attachmentSpillStorage: testChatHistory.spillStorage,
      archivedSessionStorage: testChatHistory.archivedStorage,
      httpClient: httpClient,
      processRunner: ProcessRunner(),
      accessTokenProvider: FakeAccessTokenProvider(""),
      tokenRefresher: FakeTokenRefresher(token: "token"),
      bridgeRegistrationService: createFakeBridgeRegistrationService(),
      projectGlossarySecretStorage: const FakeProjectGlossarySecretStorage(),
      failureReporter: FakeFailureReporter(),
      restartService: buildTestRestartService(),
      filesystemAccessOk: true,
      statusNotifier: null,
      reconnectBackoff: ReconnectBackoffPolicy.standard,
    ).create();
    final running = await startTestOrchestratorSession(session: composition.session);
    final runFuture = running.stopped;

    try {
      await relayServer.nextClient();
      expect(lifecycleService.compositionView.eligiblePluginIds, isEmpty);
      expect(pluginRuntime.activePluginIds, isEmpty);
      expect(composition.catalogImportService.latestStatuses, isEmpty);
    } finally {
      await composition.session.cancel();
      await runFuture.timeout(const Duration(seconds: 5));
      await composition.catalogImportService.dispose();
      await lifecycleService.dispose();
      await pluginRuntime.dispose();
      httpClient.close();
      await database.close();
      await relayServer.close();
    }
  });

  test("shutdown during the initial relay handshake returns cancelled promptly", () async {
    final rawServer = await ServerSocket.bind("127.0.0.1", 0);
    final accepted = Completer<Socket>();
    Socket? acceptedSocket;
    rawServer.listen((socket) {
      if (accepted.isCompleted) {
        socket.destroy();
        return;
      }
      acceptedSocket = socket;
      accepted.complete(socket);
    });
    addTearDown(() async {
      acceptedSocket?.destroy();
      await rawServer.close();
    });

    final database = createTestDatabase();
    addTearDown(database.close);
    final plugin = FakeBridgePlugin();
    final lifecycleService = await createSinglePluginLifecycleService(plugin: plugin);
    addTearDown(lifecycleService.dispose);
    final httpClient = http.Client();
    addTearDown(httpClient.close);
    final relayClient = RelayClient(
      relayURL: "ws://127.0.0.1:${rawServer.port}",
      accessTokenProvider: FakeAccessTokenProvider(""),
      bridgeIdProvider: FakeBridgeIdProvider(),
      connectTimeout: const Duration(seconds: 30),
    );
    final testChatHistory = createTestChatHistory();
    final session = Orchestrator(
      config: BridgeConfig(
        relayURL: "ws://127.0.0.1:${rawServer.port}",
        authBackendURL: "http://127.0.0.1:8080",
        sseReplayWindow: const Duration(minutes: 1),
        yolo: false,
      ),
      client: relayClient,
      pluginLifecycleService: lifecycleService,
      pluginRuntime: runtimeForLifecycleService(service: lifecycleService),
      bridgeSettingsRepository: settingsRepositoryForLifecycleService(service: lifecycleService),
      clock: const ServerClock(),
      database: database,
      chatHistoryDatabase: testChatHistory.database,
      attachmentSpillStorage: testChatHistory.spillStorage,
      archivedSessionStorage: testChatHistory.archivedStorage,
      httpClient: httpClient,
      processRunner: ProcessRunner(),
      accessTokenProvider: FakeAccessTokenProvider(""),
      tokenRefresher: FakeTokenRefresher(token: "token"),
      bridgeRegistrationService: createFakeBridgeRegistrationService(),
      projectGlossarySecretStorage: const FakeProjectGlossarySecretStorage(),
      failureReporter: FakeFailureReporter(),
      restartService: buildTestRestartService(),
      filesystemAccessOk: true,
      statusNotifier: null,
      reconnectBackoff: ReconnectBackoffPolicy.standard,
    ).create().session;

    final startFuture = session.start();
    final stopped = session.waitUntilStopped();
    stopped.ignore();
    addTearDown(() async {
      await session.cancel();
      await stopped.timeout(const Duration(seconds: 5));
    });
    await accepted.future.timeout(const Duration(seconds: 2));

    final stopwatch = Stopwatch()..start();
    await session.cancel().timeout(const Duration(seconds: 5));
    expect(
      await startFuture.timeout(const Duration(seconds: 5)),
      OrchestratorSessionStartResult.cancelled,
    );
    await stopped.timeout(const Duration(seconds: 5));
    stopwatch.stop();

    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
  });

  group("OrchestratorSession SSE error recovery", () {
    test("local plugin listeners start before an initial relay connect failure", () async {
      final plugin = _ThrowingSummaryPlugin();
      final connectGate = Completer<void>();
      final database = createTestDatabase();
      final lifecycleService = await createSinglePluginLifecycleService(plugin: plugin);
      final httpClient = http.Client();
      final testChatHistory = createTestChatHistory();
      final orchestrator = Orchestrator(
        config: const BridgeConfig(
          relayURL: "ws://127.0.0.1:9999",
          authBackendURL: "http://127.0.0.1:8080",
          sseReplayWindow: Duration(minutes: 1),
          yolo: false,
        ),
        client: _ThrowingConnectRelayClient(connectGate: connectGate.future),
        pluginLifecycleService: lifecycleService,
        pluginRuntime: runtimeForLifecycleService(service: lifecycleService),
        bridgeSettingsRepository: settingsRepositoryForLifecycleService(service: lifecycleService),
        clock: const ServerClock(),
        database: database,
        chatHistoryDatabase: testChatHistory.database,
        attachmentSpillStorage: testChatHistory.spillStorage,
        archivedSessionStorage: testChatHistory.archivedStorage,
        httpClient: httpClient,
        processRunner: ProcessRunner(),
        accessTokenProvider: FakeAccessTokenProvider(""),
        tokenRefresher: FakeTokenRefresher(token: "token"),
        bridgeRegistrationService: createFakeBridgeRegistrationService(),
        projectGlossarySecretStorage: const FakeProjectGlossarySecretStorage(),
        failureReporter: FakeFailureReporter(),
        restartService: buildTestRestartService(),
        filesystemAccessOk: true,
        statusNotifier: null,
        reconnectBackoff: ReconnectBackoffPolicy.standard,
      );

      final session = orchestrator.create().session;

      await expectLater(session.waitUntilStopped(), throwsA(isA<StateError>()));
      final localWireEventsDone = session.localWireEvents.drain<void>();
      final localPluginEvent = session.localWireEvents.firstWhere((event) => event is SesoriVcsBranchUpdated);
      final startFuture = session.start();
      final stopped = session.waitUntilStopped();
      stopped.ignore();
      expect(identical(stopped, session.waitUntilStopped()), isTrue);

      plugin.add(const BridgeSseVcsBranchUpdated());
      expect(await localPluginEvent.timeout(const Duration(seconds: 2)), isA<SesoriVcsBranchUpdated>());
      connectGate.complete();

      await expectLater(
        startFuture,
        throwsA(isA<StateError>().having((error) => error.message, "message", "connect failed")),
      );
      await expectLater(
        stopped,
        throwsA(isA<StateError>().having((error) => error.message, "message", "connect failed")),
      );
      await expectLater(localWireEventsDone, completes);
      await expectLater(session.start(), throwsA(isA<StateError>()));

      expect(plugin.subscribeCount, equals(2));

      await lifecycleService.dispose();
      httpClient.close();
      await plugin.close();
      await database.close();
    });

    test("stream continues when an activity source throws", () async {
      final harness = await _TestHarness.start(
        plugin: _ThrowingSummaryPlugin(),
      );
      addTearDown(harness.close);

      await harness.waitForSubscription();

      final laterEvent = harness.session.localWireEvents.firstWhere(
        (event) => event is SesoriVcsBranchUpdated,
      );
      harness.plugin.add(const BridgeSseProjectUpdated());
      harness.plugin.add(const BridgeSseVcsBranchUpdated());

      expect(await laterEvent.timeout(const Duration(seconds: 2)), isA<SesoriVcsBranchUpdated>());
    });

    test("startup and reconnect activity failures do not stop plugin events", () async {
      final harness = await _TestHarness.start(
        plugin: _ThrowingSummaryPlugin(),
      );
      addTearDown(harness.close);

      await harness.waitForSubscription();
      final laterEvent = harness.session.localWireEvents.firstWhere(
        (event) => event is SesoriVcsBranchUpdated,
      );
      harness.plugin.add(const BridgeSseServerConnected());
      harness.plugin.add(const BridgeSseVcsBranchUpdated());

      expect(await laterEvent.timeout(const Duration(seconds: 2)), isA<SesoriVcsBranchUpdated>());
      expect(harness.plugin.subscribeCount, 2);
    });
  });
}

class _TestHarness._({
  required final _ThrowingSummaryPlugin plugin,
  required final OrchestratorSession session,
  required final Future<void> runFuture,
  required final TestRelayServer relayServer,
  required final AppDatabase database,
  required final PluginLifecycleService lifecycleService,
  required final http.Client httpClient,
}) {
  static Future<_TestHarness> start({
    required _ThrowingSummaryPlugin plugin,
  }) async {
    final relayServer = await TestRelayServer.start();
    final database = createTestDatabase();
    final failureReporter = CapturingFailureReporter();
    final tokenRefresher = FakeTokenRefresher(token: "token");
    final relayClient = RelayClient(
      relayURL: "ws://127.0.0.1:${relayServer.port}",
      accessTokenProvider: FakeAccessTokenProvider(""),
      bridgeIdProvider: FakeBridgeIdProvider(),
    );

    final lifecycleService = await createSinglePluginLifecycleService(plugin: plugin);
    final httpClient = http.Client();
    final testChatHistory = createTestChatHistory();
    final orchestrator = Orchestrator(
      config: BridgeConfig(
        relayURL: "ws://127.0.0.1:${relayServer.port}",
        authBackendURL: "http://127.0.0.1:8080",
        sseReplayWindow: const Duration(minutes: 1),
        yolo: false,
      ),
      client: relayClient,
      pluginLifecycleService: lifecycleService,
      pluginRuntime: runtimeForLifecycleService(service: lifecycleService),
      bridgeSettingsRepository: settingsRepositoryForLifecycleService(service: lifecycleService),
      clock: const ServerClock(),
      database: database,
      chatHistoryDatabase: testChatHistory.database,
      attachmentSpillStorage: testChatHistory.spillStorage,
      archivedSessionStorage: testChatHistory.archivedStorage,
      httpClient: httpClient,
      processRunner: ProcessRunner(),
      accessTokenProvider: FakeAccessTokenProvider(""),
      tokenRefresher: tokenRefresher,
      bridgeRegistrationService: createFakeBridgeRegistrationService(),
      projectGlossarySecretStorage: const FakeProjectGlossarySecretStorage(),
      failureReporter: failureReporter,
      restartService: buildTestRestartService(),
      filesystemAccessOk: true,
      statusNotifier: null,
      reconnectBackoff: ReconnectBackoffPolicy.standard,
    );

    final session = orchestrator.create().session;
    final running = await startTestOrchestratorSession(session: session);
    final runFuture = running.stopped;

    await relayServer.nextClient();

    return _TestHarness._(
      plugin: plugin,
      session: session,
      runFuture: runFuture,
      relayServer: relayServer,
      database: database,
      lifecycleService: lifecycleService,
      httpClient: httpClient,
    );
  }

  Future<void> waitForSubscription() async {
    final timeoutAt = DateTime.now().add(const Duration(seconds: 2));
    while (plugin.subscribeCount == 0) {
      if (DateTime.now().isAfter(timeoutAt)) {
        fail("Timed out waiting for plugin event subscription");
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> close() async {
    await session.cancel();
    await runFuture.timeout(const Duration(seconds: 5));
    await lifecycleService.dispose();
    httpClient.close();
    await plugin.close();
    await database.close();
    await relayServer.close();
  }
}

class _ThrowingSummaryPlugin() implements NativeProjectsPluginApi {
  @override
  Future<List<PluginQueuedPrompt>> getQueuedPrompts({required String sessionId}) async => const [];

  @override
  Future<bool> cancelQueuedPrompt({required String sessionId, required String promptId}) async => false;

  final _controller = StreamController<BridgeSseEvent>.broadcast();

  int subscribeCount = 0;

  @override
  String get id => "throwing-summary";

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

  void add(BridgeSseEvent event) => _controller.add(event);

  Future<void> close() => _controller.close();

  @override
  Future<List<PluginProject>> getProjects() async => [];

  @override
  Future<List<PluginSession>> getSessions({
    required String projectId,
    required int? start,
    required int? limit,
  }) async => [];

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required String? userVisibleText,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async => const PluginSession(
    id: "",
    projectID: "",
    directory: "",
    parentID: null,
    title: null,
    time: null,
  );

  @override
  Future<PluginSession> renameSession({
    required String sessionId,
    required String title,
  }) async => const PluginSession(
    id: "",
    projectID: "",
    directory: "",
    parentID: null,
    title: null,
    time: null,
  );

  @override
  Future<PluginProject> renameProject({
    required String projectId,
    required String name,
  }) async => const PluginProject(id: "", directory: "");

  @override
  Future<void> deleteSession(String sessionId) async {}

  @override
  Future<void> archiveSession({required String sessionId}) async {}

  @override
  Future<void> deleteWorkspace({
    required String projectId,
    required String worktreePath,
  }) async {}

  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) async => [];

  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() async => {};

  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(
    String sessionId,
  ) async => [];

  @override
  Future<void> sendPrompt({
    required String promptId,
    required String sessionId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {}

  @override
  Future<void> abortSession({required String sessionId}) async {}

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) async => [];

  @override
  Future<List<PluginPendingPermission>> getPendingPermissions({
    required String sessionId,
  }) async => [];

  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({
    required String sessionId,
  }) async => [];

  @override
  Future<List<PluginPendingQuestion>> getProjectQuestions({
    required String projectId,
  }) async => [];

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
    throw StateError("summary mapping failed");
  }

  @override
  Future<List<PluginCommand>> getCommands({required String? projectId}) async => [];

  @override
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) => throw UnimplementedError();

  @override
  Future<void> sendCommand({
    required String promptId,
    required String sessionId,
    required String command,
    required String arguments,
    required String? userVisibleArguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {}

  @override
  Future<PluginProvidersResult> getProviders({
    required String projectId,
  }) async => const PluginProvidersResult(providers: []);

  Future<void> dispose() async {}
}

class _ThrowingConnectRelayClient({required final Future<void> _connectGate}) extends RelayClient {
  this
    : super(
        relayURL: "ws://127.0.0.1:1",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );

  @override
  Future<RelayConnection> connect() async {
    await _connectGate;
    throw StateError("connect failed");
  }
}
