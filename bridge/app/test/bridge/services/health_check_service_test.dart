import "package:sesori_bridge/src/bridge/models/bridge_config.dart";
import "package:sesori_bridge/src/bridge/services/health_check_service.dart";
import "package:sesori_bridge/src/repositories/server_health_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../routing/routing_test_helpers.dart";

void main() {
  group("HealthCheckService", () {
    test("check combines repository health config and server state", () async {
      final plugin = _HealthCheckBridgePlugin(healthCheckResult: false);
      final service = HealthCheckService(
        repository: ServerHealthRepository(plugin: plugin),
        readServerState: () => ServerStateKind.restarting,
        config: const BridgeConfig(
          relayURL: "ws://127.0.0.1:9999",
          serverURL: "http://127.0.0.1:4096",
          serverPassword: null,
          authBackendURL: "https://api.sesori.test",
          sseReplayWindow: Duration(minutes: 5),
          version: "1.2.3",
          serverManaged: false,
        ),
      );

      final response = await service.check();

      expect(
        response,
        equals(
          const HealthResponse(
            healthy: false,
            version: "1.2.3",
            serverManaged: false,
            serverState: ServerStateKind.restarting,
          ),
        ),
      );
      expect(plugin.healthCheckCallCount, equals(1));
    });
  });
}

class _HealthCheckBridgePlugin extends FakeBridgePlugin {
  final bool healthCheckResult;
  int healthCheckCallCount = 0;

  _HealthCheckBridgePlugin({required this.healthCheckResult});

  @override
  Future<bool> healthCheck() async {
    healthCheckCallCount++;
    return healthCheckResult;
  }
}
