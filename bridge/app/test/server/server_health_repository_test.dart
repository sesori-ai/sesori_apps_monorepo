import "package:sesori_bridge/src/repositories/server_health_repository.dart";
import "package:test/test.dart";

import "../bridge/routing/routing_test_helpers.dart";

void main() {
  group("ServerHealthRepository", () {
    test("healthCheck delegates to plugin and returns the same boolean", () async {
      final plugin = _HealthCheckBridgePlugin(healthCheckResult: false);
      final repository = ServerHealthRepository(plugin: plugin);

      final result = await repository.healthCheck();

      expect(result, isFalse);
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
