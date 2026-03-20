import "package:sesori_bridge/src/bridge/routing/abort_session_handler.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("AbortSessionHandler", () {
    late FakeBridgePlugin plugin;
    late AbortSessionHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      handler = AbortSessionHandler(plugin);
    });

    tearDown(() => plugin.close());

    test("canHandle POST /session/:id/abort", () {
      expect(handler.canHandle(makeRequest("POST", "/session/s1/abort")), isTrue);
    });

    test("extracts id", () async {
      await handler.handle(
        makeRequest("POST", "/session/s1/abort"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(plugin.lastAbortSessionId, equals("s1"));
    });

    test("returns 200", () async {
      final response = await handler.handle(
        makeRequest("POST", "/session/s1/abort"),
        pathParams: {"id": "s1"},
        queryParams: {},
      );

      expect(response.status, equals(200));
    });

    test("records id", () async {
      await handler.handle(
        makeRequest("POST", "/session/session-xyz/abort"),
        pathParams: {"id": "session-xyz"},
        queryParams: {},
      );

      expect(plugin.lastAbortSessionId, equals("session-xyz"));
    });
  });
}
