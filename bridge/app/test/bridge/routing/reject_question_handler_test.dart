import "package:sesori_bridge/src/bridge/routing/reject_question_handler.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("RejectQuestionHandler", () {
    late FakeBridgePlugin plugin;
    late RejectQuestionHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      handler = RejectQuestionHandler(plugin);
    });

    tearDown(() => plugin.close());

    test("canHandle POST /question/:id/reject", () {
      expect(handler.canHandle(makeRequest("POST", "/question/q1/reject")), isTrue);
    });

    test("extracts id and records reject call", () async {
      await handler.handle(
        makeRequest("POST", "/question/q1/reject"),
        pathParams: {"id": "q1"},
        queryParams: {},
      );

      expect(plugin.lastRejectQuestionId, equals("q1"));
    });

    test("returns 200", () async {
      final response = await handler.handle(
        makeRequest("POST", "/question/q1/reject"),
        pathParams: {"id": "q1"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(response.body, isNull);
    });
  });
}
