import "dart:async";

import "package:http/http.dart" as http;
import "package:sesori_bridge/src/auth/token_refresher.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/models/bridge_config.dart";
import "package:sesori_bridge/src/bridge/orchestrator.dart";
import "package:sesori_bridge/src/bridge/relay_client.dart";
import "package:sesori_bridge/src/bridge/runtime/bridge_runtime.dart";
import "package:sesori_bridge/src/services/plugin_lifecycle_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/plugin_lifecycle_test_support.dart";
import "../helpers/restart_test_support.dart";
import "../helpers/test_database.dart";
import "../helpers/test_helpers.dart";
import "routing/routing_test_helpers.dart";

void main() {
  test("orchestrator composes plugin discovery from one ordered lifecycle view", () async {
    final harness = await _OrchestratorHarness.create(pluginIds: const ["one", "two"]);
    addTearDown(harness.close);

    final response = await harness.composition.session.router.route(makeRequest("GET", "/plugin"));
    final plugins = PluginListResponse.fromJson(jsonDecodeMap(response.body!)).plugins;

    expect(response.status, 200);
    expect(plugins.map((plugin) => plugin.id), ["one", "two"]);
    expect(plugins.map((plugin) => plugin.isDefault), [true, false]);
    expect(plugins.map((plugin) => plugin.state), everyElement(PluginLifecycleState.ready));
  });

  test("a sourced reconnect reconciles only its plugin and local events are already mapped", () async {
    final relayServer = await TestRelayServer.start();
    final harness = await _OrchestratorHarness.create(
      pluginIds: const ["one", "two"],
      relayUrl: "ws://127.0.0.1:${relayServer.port}",
    );
    addTearDown(() async {
      await harness.close();
      await relayServer.close();
    });

    final runFuture = harness.composition.session.run();
    unawaited(runFuture.catchError((_) {}));
    await relayServer.nextClient();
    await _waitFor(
      () => harness.plugins.every((plugin) => plugin.getProjectsCallCount > 0),
      reason: "startup activity reconciliation",
    );
    final before = [for (final plugin in harness.plugins) plugin.getProjectsCallCount];

    harness.plugins.first.emitEvent(const BridgeSseServerConnected());
    await _waitFor(
      () => harness.plugins.first.getProjectsCallCount > before.first,
      reason: "source reconnect reconciliation",
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(harness.plugins.last.getProjectsCallCount, before.last);

    final localEvent = harness.composition.session.localWireEvents.firstWhere(
      (event) => event is SesoriVcsBranchUpdated,
    );
    harness.plugins.first.emitEvent(const BridgeSseVcsBranchUpdated());
    expect(await localEvent.timeout(const Duration(seconds: 2)), isA<SesoriVcsBranchUpdated>());

    await harness.composition.session.cancel();
    await runFuture.timeout(const Duration(seconds: 5));
  });
}

Future<void> _waitFor(bool Function() condition, {required String reason}) async {
  final timeoutAt = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(timeoutAt)) {
      fail("Timed out waiting for $reason");
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _OrchestratorHarness {
  final List<_SourcedPlugin> plugins;
  final PluginLifecycleService lifecycleService;
  final OrchestratorComposition composition;
  final BridgeRuntime runtime;
  final http.Client httpClient;

  const _OrchestratorHarness({
    required this.plugins,
    required this.lifecycleService,
    required this.composition,
    required this.runtime,
    required this.httpClient,
  });

  static Future<_OrchestratorHarness> create({
    required List<String> pluginIds,
    String relayUrl = "ws://127.0.0.1:1",
  }) async {
    final plugins = [for (final id in pluginIds) _SourcedPlugin(id)];
    final lifecycleService = await createPluginLifecycleService(plugins: plugins);
    final database = createTestDatabase();
    final httpClient = http.Client();
    final failureReporter = FakeFailureReporter();
    final restartService = buildTestRestartService();
    final composition = Orchestrator(
      config: BridgeConfig(
        relayURL: relayUrl,
        authBackendURL: "https://api.sesori.test",
        sseReplayWindow: const Duration(minutes: 1),
        yolo: false,
      ),
      client: RelayClient(
        relayURL: relayUrl,
        accessTokenProvider: FakeAccessTokenProvider(),
        bridgeIdProvider: FakeBridgeIdProvider(),
      ),
      legacyMissingPluginId: "opencode",
      pluginLifecycleService: lifecycleService,
      database: database,
      httpClient: httpClient,
      processRunner: ProcessRunner(),
      accessTokenProvider: FakeAccessTokenProvider(),
      tokenRefresher: _FakeTokenRefresher(),
      bridgeRegistrationService: createFakeBridgeRegistrationService(),
      failureReporter: failureReporter,
      restartService: restartService,
      filesystemAccessOk: true,
      statusNotifier: null,
    ).create();
    final runtime = BridgeRuntime(
      database: database,
      failureReporter: failureReporter,
      restartService: restartService,
      composition: composition,
    );
    return _OrchestratorHarness(
      plugins: plugins,
      lifecycleService: lifecycleService,
      composition: composition,
      runtime: runtime,
      httpClient: httpClient,
    );
  }

  Future<void> close() async {
    await composition.session.cancel();
    await runtime.close();
    await lifecycleService.dispose();
    httpClient.close();
    for (final plugin in plugins) {
      await plugin.closeEvents();
    }
  }
}

class _SourcedPlugin extends FakeBridgePlugin {
  _SourcedPlugin(this.pluginId);

  final String pluginId;

  @override
  String get id => pluginId;
}

class _FakeTokenRefresher implements TokenRefresher {
  @override
  Future<String> getAccessToken({bool forceRefresh = false}) async => "token";
}
