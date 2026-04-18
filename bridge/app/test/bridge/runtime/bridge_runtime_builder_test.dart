import "package:fake_async/fake_async.dart";
import "package:http/http.dart" as http;
import "package:sesori_bridge/src/auth/token_refresher.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/models/bridge_config.dart";
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
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "../../helpers/test_helpers.dart";
import "../routing/routing_test_helpers.dart" show FakeBridgePlugin;

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

  test("runtime-created debug server reuses the session router", () async {
    final plugin = FakeBridgePlugin();
    final database = createTestDatabase();
    final httpClient = http.Client();
    final runtime = BridgeRuntime.create(
      config: const BridgeConfig(
        relayURL: "ws://127.0.0.1:9999",
        serverURL: "http://127.0.0.1:4096",
        serverPassword: null,
        authBackendURL: "https://api.sesori.test",
        sseReplayWindow: Duration(minutes: 5),
      ),
      plugin: plugin,
      httpClient: httpClient,
      accessTokenProvider: FakeAccessTokenProvider(),
      tokenRefresher: _FakeTokenRefresher(),
      database: database,
      processRunner: ProcessRunner(),
      failureReporter: FakeFailureReporter(),
    );
    final debugServer = runtime.createDebugServer(port: 0);

    expect(identical(debugServer.router, runtime.session.router), isTrue);

    await debugServer.stop();
    await runtime.close();
    httpClient.close();
    await plugin.dispose();
  });
}

class _FakeTokenRefresher implements TokenRefresher {
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
