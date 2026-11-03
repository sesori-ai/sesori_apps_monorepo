import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_bridge/src/foundation/process_runner.dart";
import "package:sesori_bridge/src/foundation/relay_client.dart";
import "package:sesori_bridge/src/models/bridge_config.dart";
import "package:sesori_bridge/src/orchestrator.dart";
import "package:sesori_bridge/src/routing/routed_request_dispatcher.dart";
import "package:sesori_bridge/src/runtime/bridge_runtime.dart";
import "package:sesori_bridge/src/services/bridge_startup_retry_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show ServerClock;
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/plugin_lifecycle_test_support.dart";
import "../../helpers/test_chat_history.dart";
import "../../helpers/test_database.dart";
import "../../helpers/test_helpers.dart";
import "../routing/routing_test_helpers.dart" show FakeBridgePlugin, makeRequest;

void main() {
  test("runtime-created debug server reuses the composed routed request dispatcher", () async {
    final plugin = FakeBridgePlugin();
    final database = createTestDatabase();
    final httpClient = http.Client();
    final lifecycleService = await createSinglePluginLifecycleService(plugin: plugin);
    final failureReporter = FakeFailureReporter();
    final testChatHistory = createTestChatHistory();
    final composition = Orchestrator(
      connectionNotificationPolicies: const Stream.empty(),
      config: const BridgeConfig(
        relayURL: "ws://127.0.0.1:9999",
        authBackendURL: "https://api.sesori.test",
        sseReplayWindow: Duration(minutes: 5),
        yolo: false,
      ),
      client: RelayClient(
        relayURL: "ws://127.0.0.1:9999",
        accessTokenProvider: FakeAccessTokenProvider(),
        bridgeIdProvider: FakeBridgeIdProvider(),
      ),
      pluginLifecycleRepository: lifecycleRepositoryForLifecycleService(service: lifecycleService),
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
      accessTokenProvider: FakeAccessTokenProvider(),
      tokenRefresher: FakeTokenRefresher(),
      bridgeRegistrationService: createFakeBridgeRegistrationService(),
      failureReporter: failureReporter,
      filesystemAccessOk: true,
      bridgeKind: BridgeKind.cli,
      statusNotifier: null,
      startupRetryService: BridgeStartupRetryService(),
      reconnectBackoff: ReconnectBackoffPolicy.standard,
    ).create();
    final runtime = BridgeRuntime(
      database: database,
      chatHistoryDatabase: testChatHistory.database,
      failureReporter: failureReporter,
      composition: composition,
    );
    final debugServer = runtime.createDebugServer(port: 0);

    expect(identical(debugServer.routedRequestDispatcher, runtime.session.routedRequestDispatcher), isTrue);
    final dispatch = debugServer.routedRequestDispatcher.dispatch(
      request: makeRequest(
        "POST",
        "/session/options",
        body: jsonEncode(PluginProjectIdRequest(projectId: "missing", pluginId: plugin.id).toJson()),
      ),
    );
    expect(dispatch, isA<RoutedRequestAccepted>());
    final routed = await (dispatch as RoutedRequestAccepted).pendingRequest.completion;
    expect(routed.status, 404);
    expect(routed.headers, containsPair("content-type", "application/json"));
    expect(
      SessionOptionsErrorResponse.fromJson(jsonDecodeMap(routed.body ?? fail("missing body"))).code,
      SessionOptionsErrorCode.projectNotFound,
    );

    debugServer.beginShutdown();
    final rejected = runtime.session.routedRequestDispatcher.dispatch(
      request: makeRequest("GET", "/global/health"),
    );
    expect(rejected, isA<RoutedRequestShutdownRejected>());
    expect((rejected as RoutedRequestShutdownRejected).response.status, 503);
    await debugServer.drain();
    await runtime.close();
    await lifecycleService.dispose();
    httpClient.close();
    await plugin.closeEvents();
  });
}
