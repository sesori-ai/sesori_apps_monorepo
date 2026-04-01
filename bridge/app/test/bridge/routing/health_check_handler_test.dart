import "package:sesori_bridge/src/bridge/routing/health_check_handler.dart";
import "package:sesori_shared/sesori_shared.dart";
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

    test("returns success response", () async {
      final response = await handler.handle(
        makeRequest("GET", "/global/health"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
      expect(response, equals(const SuccessEmptyResponse()));
    });
  });
}
