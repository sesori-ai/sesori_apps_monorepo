import "package:fake_async/fake_async.dart";
import "package:http/http.dart" as http;
import "package:sesori_bridge/src/auth/token_refresher.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/models/bridge_config.dart";
import "package:sesori_bridge/src/bridge/runtime/bridge_runtime.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";
import "../../helpers/test_helpers.dart";
import "../routing/routing_test_helpers.dart" show FakeBridgePlugin;

void main() {
  test("push subsystem listeners stay passive during runtime composition", () {
    fakeAsync((async) {
      final pushSubsystem = createPushSubsystem(
        authBackendURL: "https://api.sesori.test",
        tokenRefresher: _FakeTokenRefresher(),
      );

      expect(pushSubsystem.completionListener.isStarted, isFalse);
      expect(pushSubsystem.maintenanceListener.isStarted, isFalse);
      expect(pushSubsystem.dispatcher.lastMaintenanceTelemetry, isNull);

      async.elapse(const Duration(minutes: 10));

      expect(pushSubsystem.dispatcher.lastMaintenanceTelemetry, isNull);
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
