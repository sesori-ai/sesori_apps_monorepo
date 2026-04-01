import "package:sesori_bridge/src/bridge/routing/health_check_handler.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("HealthCheckHandler", () {
    late FakeBridgePlugin plugin;
    late HealthCheckHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      handler = HealthCheckHandler(plugin);
    });

    tearDown(() => plugin.close());

    test("canHandle GET /global/health", () {
      expect(handler.canHandle(makeRequest("GET", "/global/health")), isTrue);
    });

    test("does not handle POST /global/health", () {
      expect(handler.canHandle(makeRequest("POST", "/global/health")), isFalse);
    });

    test("does not handle a different path", () {
      expect(handler.canHandle(makeRequest("GET", "/project")), isFalse);
    });

    test("returns 200", () async {
      final response = await handler.handleInternal(
        makeRequest("GET", "/global/health"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(response.status, equals(200));
    });

    test("returns application/json content-type", () async {
      final response = await handler.handleInternal(
        makeRequest("GET", "/global/health"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(response.headers["content-type"], equals("application/json"));
    });
  });
}
