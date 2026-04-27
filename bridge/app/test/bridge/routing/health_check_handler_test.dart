import "package:sesori_bridge/src/bridge/models/bridge_config.dart";
import "package:sesori_bridge/src/bridge/routing/health_check_handler.dart";
import "package:sesori_bridge/src/bridge/services/health_check_service.dart";
import "package:sesori_bridge/src/repositories/server_health_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("HealthCheckHandler", () {
    late FakeBridgePlugin plugin;
    late HealthCheckHandler handler;
    late BridgeConfig config;

    setUp(() {
      plugin = FakeBridgePlugin();
      config = const BridgeConfig(
        relayURL: "ws://127.0.0.1:9999",
        serverURL: "http://127.0.0.1:4096",
        serverPassword: null,
        authBackendURL: "https://api.sesori.test",
        sseReplayWindow: Duration(minutes: 5),
        version: "test",
        serverManaged: true,
      );
      handler = HealthCheckHandler(
        service: HealthCheckService(
          repository: ServerHealthRepository(plugin: plugin),
          readServerState: () => ServerStateKind.running,
          config: config,
        ),
      );
    });

    tearDown(() async {
      await plugin.close();
    });

    test("canHandle GET /global/health", () {
      expect(handler.canHandle(makeRequest("GET", "/global/health")), isTrue);
    });

    test("does not handle POST /global/health", () {
      expect(handler.canHandle(makeRequest("POST", "/global/health")), isFalse);
    });

    test("does not handle a different path", () {
      expect(handler.canHandle(makeRequest("GET", "/project")), isFalse);
    });

    test("returns success response", () async {
      final response = await handler.handle(
        makeRequest("GET", "/global/health"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(
        response,
        equals(
          const HealthResponse(
            healthy: true,
            version: "test",
            serverManaged: true,
            serverState: ServerStateKind.running,
          ),
        ),
      );
    });

    test("handle returns health response from service", () async {
      final unhealthyPlugin = _HealthCheckBridgePlugin(healthCheckResult: false);
      final customHandler = HealthCheckHandler(
        service: HealthCheckService(
          repository: ServerHealthRepository(plugin: unhealthyPlugin),
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
        ),
      );

      final response = await customHandler.handle(
        makeRequest("GET", "/global/health"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

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
    });

    test("healthy is true when healthCheck returns true", () async {
      final healthyPlugin = _HealthCheckBridgePlugin(healthCheckResult: true);
      final localHandler = HealthCheckHandler(
        service: HealthCheckService(
          repository: ServerHealthRepository(plugin: healthyPlugin),
          readServerState: () => ServerStateKind.running,
          config: config,
        ),
      );

      final response = await localHandler.handle(
        makeRequest("GET", "/global/health"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.healthy, isTrue);
    });

    test("healthy is false when healthCheck returns false", () async {
      final unhealthyPlugin = _HealthCheckBridgePlugin(healthCheckResult: false);
      final localHandler = HealthCheckHandler(
        service: HealthCheckService(
          repository: ServerHealthRepository(plugin: unhealthyPlugin),
          readServerState: () => ServerStateKind.running,
          config: config,
        ),
      );

      final response = await localHandler.handle(
        makeRequest("GET", "/global/health"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.healthy, isFalse);
    });

    test("version comes from BridgeConfig.version", () async {
      final customHandler = HealthCheckHandler(
        service: HealthCheckService(
          repository: ServerHealthRepository(
            plugin: _HealthCheckBridgePlugin(healthCheckResult: true),
          ),
          readServerState: () => ServerStateKind.running,
          config: const BridgeConfig(
            relayURL: "ws://127.0.0.1:9999",
            serverURL: "http://127.0.0.1:4096",
            serverPassword: null,
            authBackendURL: "https://api.sesori.test",
            sseReplayWindow: Duration(minutes: 5),
            version: "9.9.9",
            serverManaged: true,
          ),
        ),
      );

      final response = await customHandler.handle(
        makeRequest("GET", "/global/health"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.version, equals("9.9.9"));
    });

    test("serverManaged comes from BridgeConfig.serverManaged", () async {
      final customHandler = HealthCheckHandler(
        service: HealthCheckService(
          repository: ServerHealthRepository(
            plugin: _HealthCheckBridgePlugin(healthCheckResult: true),
          ),
          readServerState: () => ServerStateKind.running,
          config: const BridgeConfig(
            relayURL: "ws://127.0.0.1:9999",
            serverURL: "http://127.0.0.1:4096",
            serverPassword: null,
            authBackendURL: "https://api.sesori.test",
            sseReplayWindow: Duration(minutes: 5),
            version: "test",
            serverManaged: false,
          ),
        ),
      );

      final response = await customHandler.handle(
        makeRequest("GET", "/global/health"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.serverManaged, isFalse);
    });

    test("serverState comes from HealthCheckService state reader", () async {
      final customHandler = HealthCheckHandler(
        service: HealthCheckService(
          repository: ServerHealthRepository(
            plugin: _HealthCheckBridgePlugin(healthCheckResult: true),
          ),
          readServerState: () => ServerStateKind.failed,
          config: config,
        ),
      );

      final response = await customHandler.handle(
        makeRequest("GET", "/global/health"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.serverState, equals(ServerStateKind.failed));
    });
  });
}

class _HealthCheckBridgePlugin extends FakeBridgePlugin {
  final bool healthCheckResult;

  _HealthCheckBridgePlugin({required this.healthCheckResult});

  @override
  Future<bool> healthCheck() async {
    return healthCheckResult;
  }
}
