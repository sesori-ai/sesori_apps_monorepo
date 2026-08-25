import "dart:async";
import "dart:convert";
import "dart:io";

import "package:fake_async/fake_async.dart";
import "package:http/http.dart" as http;
import "package:sesori_bridge/src/auth/token_refresher.dart";
import "package:sesori_bridge/src/bridge/device_canvas/protocol.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/models/bridge_config.dart";
import "package:sesori_bridge/src/bridge/orchestrator.dart";
import "package:sesori_bridge/src/bridge/relay_client.dart";
import "package:sesori_bridge/src/bridge/routing/routed_request_dispatcher.dart";
import "package:sesori_bridge/src/bridge/runtime/bridge_runtime.dart";
import "package:sesori_bridge/src/push/completion_notifier.dart";
import "package:sesori_bridge/src/push/completion_push_listener.dart";
import "package:sesori_bridge/src/push/maintenance_push_listener.dart";
import "package:sesori_bridge/src/push/push_dispatcher.dart";
import "package:sesori_bridge/src/push/push_maintenance_telemetry.dart" show PushMaintenanceTelemetryBuilder;
import "package:sesori_bridge/src/push/push_notification_client.dart";
import "package:sesori_bridge/src/push/push_notification_content_builder.dart";
import "package:sesori_bridge/src/push/push_rate_limiter.dart";
import "package:sesori_bridge/src/push/push_session_state_tracker.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show ServerClock;
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/plugin_lifecycle_test_support.dart";
import "../../helpers/restart_test_support.dart";
import "../../helpers/test_chat_history.dart";
import "../../helpers/test_database.dart";
import "../../helpers/test_helpers.dart";
import "../routing/routing_test_helpers.dart" show FakeBridgePlugin, makeRequest;

void main() {
  test("push subsystem listeners stay passive during runtime composition", () {
    fakeAsync((async) {
      final pushSubsystem = _createPushSubsystemForTest();

      expect(pushSubsystem.completionListener.isStarted, isFalse);
      expect(pushSubsystem.maintenanceListener.isStarted, isFalse);
      expect(pushSubsystem.maintenanceListener.lastMaintenanceTelemetry, isNull);

      async.elapse(const Duration(minutes: 10));

      expect(pushSubsystem.maintenanceListener.lastMaintenanceTelemetry, isNull);
      expect(pushSubsystem.completionListener.isStarted, isFalse);
      expect(pushSubsystem.maintenanceListener.isStarted, isFalse);
    });
  });

  test("runtime-created debug server reuses the composed routed request dispatcher", () async {
    final plugin = FakeBridgePlugin();
    final database = createTestDatabase();
    final httpClient = http.Client();
    final lifecycleService = await createSinglePluginLifecycleService(plugin: plugin);
    final failureReporter = FakeFailureReporter();
    final restartService = buildTestRestartService();
    final testChatHistory = createTestChatHistory();
    final composition = Orchestrator(
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
      legacyMissingPluginId: plugin.id,
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
      tokenRefresher: _FakeTokenRefresher(),
      bridgeRegistrationService: createFakeBridgeRegistrationService(),
      failureReporter: failureReporter,
      restartService: restartService,
      filesystemAccessOk: true,
      statusNotifier: null,
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
    final routed = (await (dispatch as RoutedRequestAccepted).pendingRequest.completion).response;
    expect(routed.status, 404);
    expect(routed.headers, containsPair("content-type", "application/json"));
    expect(
      SessionOptionsErrorResponse.fromJson(jsonDecodeMap(routed.body!)).code,
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
    await plugin.dispose();
  });

  test("Device Canvas IPC rotates rendezvous, secret, and peer after bridge re-registration", () async {
    final plugin = FakeBridgePlugin();
    final database = createTestDatabase();
    final httpClient = http.Client();
    final lifecycleService = await createSinglePluginLifecycleService(plugin: plugin);
    final failureReporter = FakeFailureReporter();
    final restartService = buildTestRestartService();
    final testChatHistory = createTestChatHistory();
    final tempDir = await Directory.systemTemp.createTemp("device-canvas-runtime-rotation-");
    final registrations = StreamController<String>.broadcast(sync: true);
    addTearDown(() async {
      await registrations.close();
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });
    final composition = Orchestrator(
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
      legacyMissingPluginId: plugin.id,
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
      tokenRefresher: _FakeTokenRefresher(),
      bridgeRegistrationService: createFakeBridgeRegistrationService(),
      failureReporter: failureReporter,
      restartService: restartService,
      filesystemAccessOk: true,
      statusNotifier: null,
      reconnectBackoff: ReconnectBackoffPolicy.standard,
    ).create();
    final runtime = BridgeRuntime(
      database: database,
      chatHistoryDatabase: testChatHistory.database,
      failureReporter: failureReporter,
      composition: composition,
    );

    await runtime.startDeviceCanvasIpcServer(
      dataDirectory: tempDir.path,
      bridgeId: "bridge-a",
      processGeneration: "test:initial",
      bridgeRegistrations: registrations.stream,
    );
    final initial = await _readDeviceCanvasRendezvous(tempDir: tempDir);
    expect(initial["bridgeId"], "bridge-a");
    final oldPeer = await _connectDeviceCanvasPeer(initial);
    final oldDone = Completer<void>();
    oldPeer.listen(null, onDone: oldDone.complete);

    registrations.add("bridge-b");
    await runtime.deviceCanvasIpcLifecycleIdle;

    await oldDone.future.timeout(const Duration(seconds: 5));
    final rotated = await _readDeviceCanvasRendezvous(tempDir: tempDir);
    expect(rotated["bridgeId"], "bridge-b");
    expect(rotated["bearerSecret"], isNot(equals(initial["bearerSecret"])));
    final newPeer = await _connectDeviceCanvasPeer(rotated);
    addTearDown(newPeer.close);
    final messages = StreamIterator<String>(newPeer.cast<String>());
    newPeer.add(
      jsonEncode({
        "type": "hello",
        "protocolVersion": deviceCanvasIpcProtocolVersion,
        "canvasInstanceId": "canvas",
        "capabilities": {"localView": true, "remoteVideo": true, "remoteControl": true, "input": true},
      }),
    );

    expect(await _nextJson(messages), containsPair("bridgeId", "bridge-b"));

    await runtime.close();
    await lifecycleService.dispose();
    httpClient.close();
    await plugin.dispose();
  });
}

Future<Map<String, dynamic>> _readDeviceCanvasRendezvous({required Directory tempDir}) async {
  return jsonDecode(await File("${tempDir.path}/device-canvas/ipc-rendezvous.json").readAsString())
      as Map<String, dynamic>;
}

Future<WebSocket> _connectDeviceCanvasPeer(Map<String, dynamic> rendezvous) {
  return WebSocket.connect(
    "ws://127.0.0.1:${rendezvous["port"]}",
    headers: {HttpHeaders.authorizationHeader: "Bearer ${rendezvous["bearerSecret"]}"},
  );
}

Future<Map<String, dynamic>> _nextJson(StreamIterator<String> messages) async {
  expect(await messages.moveNext().timeout(const Duration(seconds: 5)), isTrue);
  return jsonDecode(messages.current) as Map<String, dynamic>;
}

class _FakeTokenRefresher() implements TokenRefresher {
  @override
  Future<String> getAccessToken({bool forceRefresh = false}) async => "test-token";
}

({
  PushDispatcher dispatcher,
  CompletionPushListener completionListener,
  MaintenancePushListener maintenanceListener,
})
_createPushSubsystemForTest() {
  final tracker = PushSessionStateTracker(now: DateTime.now);
  final rateLimiter = PushRateLimiter(now: DateTime.now);
  final completionNotifier = CompletionNotifier(
    tracker: tracker,
    debounceDuration: const Duration(milliseconds: 500),
  );
  final dispatcher = PushDispatcher(
    client: PushNotificationClient(
      authBackendURL: "https://api.sesori.test",
      tokenRefreshManager: _FakeTokenRefresher(),
      client: http.Client(),
    ),
    rateLimiter: rateLimiter,
    tracker: tracker,
    contentBuilder: const PushNotificationContentBuilder(),
  );
  final telemetryBuilder = PushMaintenanceTelemetryBuilder(
    completionNotifier: completionNotifier,
    rateLimiter: rateLimiter,
    rssBytesReader: () => 0,
  );

  return (
    dispatcher: dispatcher,
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
    ),
  );
}
