import "package:sesori_bridge/src/routing/abort_session_handler.dart";
import "package:sesori_bridge/src/services/session_abort_service.dart";
import "package:sesori_bridge/src/services/session_operation_dispatcher.dart";
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
      final repository = FakeSessionRepository(plugin: plugin);
      final dispatcher = SessionOperationDispatcher(sessionRepository: repository);
      addTearDown(dispatcher.dispose);
      sessionAbortService = SessionAbortService(
        sessionRepository: repository,
        dispatcher: dispatcher,
      );
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
        body: const AbortSessionRequest(sessionId: "s1"),
      );

      expect(plugin.lastAbortSessionId, equals("s1"));
    });

    test("returns 200", () async {
      final response = await handler.handle(
        makeRequest("POST", "/session/abort"),
        body: const AbortSessionRequest(sessionId: "s1"),
      );

      expect(response, equals(const SuccessEmptyResponse()));
    });
  });
}
