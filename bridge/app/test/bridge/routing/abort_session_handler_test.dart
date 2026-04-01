import "dart:convert";

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

    test("canHandle POST /session/abort", () {
      expect(handler.canHandle(makeRequest("POST", "/session/abort")), isTrue);
    });

    test("extracts sessionId from request body", () async {
      await handler.handleInternal(
        makeRequest("POST", "/session/abort", body: jsonEncode({"sessionId": "s1"})),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastAbortSessionId, equals("s1"));
    });

    test("returns 200", () async {
      final response = await handler.handleInternal(
        makeRequest("POST", "/session/abort", body: jsonEncode({"sessionId": "s1"})),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(200));
      expect(response.body, equals("{}"));
    });

    test("records id", () async {
      await handler.handleInternal(
        makeRequest("POST", "/session/abort", body: jsonEncode({"sessionId": "session-xyz"})),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastAbortSessionId, equals("session-xyz"));
    });
  });
}
