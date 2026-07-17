import "package:sesori_bridge/src/bridge/routing/health_check_handler.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/single_plugin_repository_test_support.dart";
import "routing_test_helpers.dart";

void main() {
  group("HealthCheckHandler", () {
    late FakeBridgePlugin plugin;

    HealthCheckHandler buildHandler({bool filesystemAccessOk = true}) {
      return HealthCheckHandler(
        healthRepository: singlePluginHealthRepository(
          plugin: plugin,
          bridgeVersion: "9.9.9",
          filesystemAccessOk: filesystemAccessOk,
        ),
      );
    }

    setUp(() {
      plugin = FakeBridgePlugin();
    });

    tearDown(() => plugin.close());

    test("canHandle GET /global/health", () {
      expect(buildHandler().canHandle(makeRequest("GET", "/global/health")), isTrue);
    });

    test("does not handle POST /global/health", () {
      expect(buildHandler().canHandle(makeRequest("POST", "/global/health")), isFalse);
    });

    test("does not handle a different path", () {
      expect(buildHandler().canHandle(makeRequest("GET", "/project")), isFalse);
    });

    test("returns healthy response with version", () async {
      final response = await buildHandler().handle(
        makeRequest("GET", "/global/health"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(response.healthy, isTrue);
      expect(response.version, equals("9.9.9"));
      expect(response.filesystemAccessDegraded, isFalse);
    });

    test("reports filesystemAccessDegraded when access is not ok", () async {
      final response = await buildHandler(filesystemAccessOk: false).handle(
        makeRequest("GET", "/global/health"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(response.filesystemAccessDegraded, isTrue);
    });

    test("reports plugin health without marking the bridge unhealthy", () async {
      plugin.healthCheckResult = false;
      final response = await buildHandler().handle(
        makeRequest("GET", "/global/health"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.healthy, isTrue);
      expect(response.plugins, [const PluginHealth(pluginId: "fake", healthy: false)]);
    });
  });
}
