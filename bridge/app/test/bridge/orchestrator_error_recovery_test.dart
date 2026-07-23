import "dart:async";

import "package:http/http.dart" as http;
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/auth/token_refresher.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/models/bridge_config.dart";
import "package:sesori_bridge/src/bridge/orchestrator.dart";
import "package:sesori_bridge/src/bridge/relay_client.dart";
import "package:sesori_bridge/src/repositories/plugin_lifecycle_repository.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/plugin_lifecycle_test_support.dart";
import "../helpers/plugin_runtime_test_support.dart";
import "../helpers/restart_test_support.dart";
import "../helpers/test_database.dart";
import "../helpers/test_helpers.dart";

void main() {
  test("zero-plugin composition keeps the relay session online", () async {
    final relayServer = await TestRelayServer.start();
    final database = createTestDatabase();
    final pluginRuntime = createRegisteredTestPluginRuntime(pluginIds: const ["opencode"]);
    final lifecycleService =
        PluginLifecycleService(
            lifecycleRepository: PluginLifecycleRepository(runtime: pluginRuntime),
            preferredDefaultPluginId: legacyMissingPluginId,
          )
          ..registerPlugins(
            plugins: const [(id: "opencode", displayName: "OpenCode")],
          )
          ..initialize(
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
    final composition = Orchestrator(
      config: BridgeConfig(
        relayURL: "ws://127.0.0.1:${relayServer.port}",
        authBackendURL: "http://127.0.0.1:8080",
        sseReplayWindow: const Duration(minutes: 1),
        yolo: false,
      ),
      client: relayClient,
      legacyMissingPluginId: "opencode",
      pluginLifecycleService: lifecycleService,
      pluginRuntime: pluginRuntime,
      database: database,
      httpClient: httpClient,
      processRunner: ProcessRunner(),
      accessTokenProvider: FakeAccessTokenProvider(""),
      tokenRefresher: _FakeTokenRefresher(),
      bridgeRegistrationService: createFakeBridgeRegistrationService(),
      failureReporter: FakeFailureReporter(),
      restartService: buildTestRestartService(),
      filesystemAccessOk: true,
      statusNotifier: null,
    ).create();
    final runFuture = composition.session.run();

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

  group("OrchestratorSession SSE error recovery", () {
    test("initial relay connect failure does not leave push listeners running", () async {
      final plugin = _ThrowingSummaryPlugin();
      final database = createTestDatabase();
      final lifecycleService = await createSinglePluginLifecycleService(plugin: plugin);
      final httpClient = http.Client();
      final orchestrator = Orchestrator(
        config: const BridgeConfig(
          relayURL: "ws://127.0.0.1:9999",
          authBackendURL: "http://127.0.0.1:8080",
          sseReplayWindow: Duration(minutes: 1),
          yolo: false,
        ),
        client: _ThrowingConnectRelayClient(),
        legacyMissingPluginId: plugin.id,
        pluginLifecycleService: lifecycleService,
        pluginRuntime: runtimeForLifecycleService(service: lifecycleService),
        database: database,
        httpClient: httpClient,
        processRunner: ProcessRunner(),
        accessTokenProvider: FakeAccessTokenProvider(""),
        tokenRefresher: _FakeTokenRefresher(),
        bridgeRegistrationService: createFakeBridgeRegistrationService(),
        failureReporter: FakeFailureReporter(),
        restartService: buildTestRestartService(),
        filesystemAccessOk: true,
        statusNotifier: null,
      );

      final session = orchestrator.create().session;

      await expectLater(session.run(), throwsA(isA<Exception>()));

      expect(plugin.subscribeCount, equals(0));

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
      expect(harness.plugin.subscribeCount, 1);
    });
  });
}

class _TestHarness {
  final _ThrowingSummaryPlugin plugin;
  final OrchestratorSession session;
  final Future<void> runFuture;
  final TestRelayServer relayServer;
  final AppDatabase database;
  final PluginLifecycleService lifecycleService;
  final http.Client httpClient;

  _TestHarness._({
    required this.plugin,
    required this.session,
    required this.runFuture,
    required this.relayServer,
    required this.database,
    required this.lifecycleService,
    required this.httpClient,
  });

  static Future<_TestHarness> start({
    required _ThrowingSummaryPlugin plugin,
  }) async {
    final relayServer = await TestRelayServer.start();
    final database = createTestDatabase();
    final failureReporter = CapturingFailureReporter();
    final tokenRefresher = _FakeTokenRefresher();
    final relayClient = RelayClient(
      relayURL: "ws://127.0.0.1:${relayServer.port}",
      accessTokenProvider: FakeAccessTokenProvider(""),
      bridgeIdProvider: FakeBridgeIdProvider(),
    );

    final lifecycleService = await createSinglePluginLifecycleService(plugin: plugin);
    final httpClient = http.Client();
    final orchestrator = Orchestrator(
      config: BridgeConfig(
        relayURL: "ws://127.0.0.1:${relayServer.port}",
        authBackendURL: "http://127.0.0.1:8080",
        sseReplayWindow: const Duration(minutes: 1),
        yolo: false,
      ),
      client: relayClient,
      legacyMissingPluginId: plugin.id,
      pluginLifecycleService: lifecycleService,
      pluginRuntime: runtimeForLifecycleService(service: lifecycleService),
      database: database,
      httpClient: httpClient,
      processRunner: ProcessRunner(),
      accessTokenProvider: FakeAccessTokenProvider(""),
      tokenRefresher: tokenRefresher,
      bridgeRegistrationService: createFakeBridgeRegistrationService(),
      failureReporter: failureReporter,
      restartService: buildTestRestartService(),
      filesystemAccessOk: true,
      statusNotifier: null,
    );

    final session = orchestrator.create().session;
    final runFuture = session.run();

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

class _ThrowingSummaryPlugin implements NativeProjectsPluginApi {
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
  Future<List<PluginSession>> getSessions(
    String worktree, {
    int? start,
    int? limit,
  }) async => [];

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
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
  Future<void> sendCommand({
    required String sessionId,
    required String command,
    required String arguments,
    required PluginSessionVariant? variant,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) async {}

  @override
  Future<PluginProvidersResult> getProviders({
    required String projectId,
  }) async => const PluginProvidersResult(providers: []);

  @override
  Future<void> dispose() async {}
}

class _ThrowingConnectRelayClient extends RelayClient {
  _ThrowingConnectRelayClient()
    : super(
        relayURL: "ws://127.0.0.1:1",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );

  @override
  Future<void> connect() async {
    throw StateError("connect failed");
  }
}

class _FakeTokenRefresher implements TokenRefresher {
  @override
  Future<String> getAccessToken({bool forceRefresh = false}) async => "token";
}
