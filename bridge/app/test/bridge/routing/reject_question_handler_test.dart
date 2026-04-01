import "package:sesori_bridge/src/bridge/routing/reject_question_handler.dart";
import "package:sesori_shared/sesori_shared.dart";
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

    test("canHandle POST /question/reject", () {
      expect(handler.canHandle(makeRequest("POST", "/question/reject")), isTrue);
    });

    test("extracts requestId and records reject call", () async {
      await handler.handle(
        makeRequest("POST", "/question/reject"),
        body: const RejectQuestionRequest(requestId: "q1"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastRejectQuestionId, equals("q1"));
    });

    test("returns 200", () async {
      final response = await handler.handle(
        makeRequest("POST", "/question/reject"),
        body: const RejectQuestionRequest(requestId: "q1"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, equals(const SuccessEmptyResponse()));
    });

    test("throws 400 on empty request id", () async {
      expect(
        () => handler.handle(
          makeRequest("POST", "/question/reject"),
          body: const RejectQuestionRequest(requestId: ""),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });
  });
}
