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

    test("returns 200 with plugin health body", () async {
      final response = await handler.handle(
        makeRequest("GET", "/global/health"),
        pathParams: {},
        queryParams: {},
      );
      expect(response.status, equals(200));
      expect(response.body, equals('{"status":"ok"}'));
    });

    test("returns application/json content-type", () async {
      final response = await handler.handle(
        makeRequest("GET", "/global/health"),
        pathParams: {},
        queryParams: {},
      );
      expect(response.headers["content-type"], equals("application/json"));
    });
  });
}
