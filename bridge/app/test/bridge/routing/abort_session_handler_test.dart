import "package:sesori_bridge/src/bridge/routing/abort_session_handler.dart";
import "package:sesori_bridge/src/bridge/services/session_abort_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("AbortSessionHandler", () {
    late FakeBridgePlugin plugin;
    late AbortSessionHandler handler;
    late SessionAbortService sessionAbortService;

    setUp(() {
      plugin = FakeBridgePlugin();
      sessionAbortService = SessionAbortService(sessionRepository: FakeSessionRepository(plugin: plugin));
      handler = AbortSessionHandler(sessionAbortService: sessionAbortService);
    });

    tearDown(() async {
      await sessionAbortService.dispose();
      await plugin.close();
    });

    test("canHandle POST /session/abort", () {
      expect(handler.canHandle(makeRequest("POST", "/session/abort")), isTrue);
    });

    test("extracts sessionId from request body", () async {
      await handler.handle(
        makeRequest("POST", "/session/abort"),
        body: const SessionIdRequest(sessionId: "s1"),
        pathParams: {},
        queryParams: {},
      );

      expect(plugin.lastAbortSessionId, equals("s1"));
    });

    test("returns 200", () async {
      final response = await handler.handle(
        makeRequest("POST", "/session/abort"),
        body: const SessionIdRequest(sessionId: "s1"),
        pathParams: {},
        queryParams: {},
      );

      expect(response, equals(const SuccessEmptyResponse()));
    });

    test("records id", () async {
      await handler.handle(
        makeRequest("POST", "/session/abort"),
        body: const SessionIdRequest(sessionId: "session-xyz"),
        pathParams: {},
        queryParams: {},
      );

      expect(plugin.lastAbortSessionId, equals("session-xyz"));
    });

    test("routes abort through the session abort service", () async {
      await handler.handle(
        makeRequest("POST", "/session/abort"),
        body: const SessionIdRequest(sessionId: "s1"),
        pathParams: {},
        queryParams: {},
      );

      expect(plugin.lastAbortSessionId, equals("s1"));
    });
  });
}
