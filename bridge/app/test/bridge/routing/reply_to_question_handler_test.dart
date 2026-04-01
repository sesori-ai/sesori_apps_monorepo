import "package:sesori_bridge/src/bridge/routing/reply_to_question_handler.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("ReplyToQuestionHandler", () {
    late FakeBridgePlugin plugin;
    late ReplyToQuestionHandler handler;

    setUp(() {
      plugin = FakeBridgePlugin();
      handler = ReplyToQuestionHandler(plugin);
    });

    tearDown(() => plugin.close());

    test("canHandle POST /question/reply", () {
      expect(handler.canHandle(makeRequest("POST", "/question/reply")), isTrue);
    });

    test("extracts requestId, sessionId, and parses answers", () async {
      await handler.handle(
        makeRequest("POST", "/question/reply"),
        body: const ReplyToQuestionRequest(
          requestId: "q1",
          sessionId: "ses-1",
          answers: [
            ReplyAnswer(values: ["yes"]),
            ReplyAnswer(values: ["tool-a", "tool-b"]),
          ],
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(plugin.lastReplyQuestionId, equals("q1"));
      expect(plugin.lastReplySessionId, equals("ses-1"));
      expect(
        plugin.lastReplyAnswers,
        equals(const [
          ["yes"],
          ["tool-a", "tool-b"],
        ]),
      );
    });

    test("returns 200", () async {
      final response = await handler.handle(
        makeRequest("POST", "/question/reply"),
        body: const ReplyToQuestionRequest(
          requestId: "q1",
          sessionId: "ses-1",
          answers: [
            ReplyAnswer(values: ["ok"]),
          ],
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response, equals(const SuccessEmptyResponse()));
    });

    test("returns 400 on empty request id", () async {
      await expectLater(
        () => handler.handle(
          makeRequest("POST", "/question/reply"),
          body: const ReplyToQuestionRequest(
            requestId: "",
            sessionId: "ses-1",
            answers: [
              ReplyAnswer(values: ["ok"]),
            ],
          ),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });

    test("returns 400 on empty session id", () async {
      expect(
        () => handler.handle(
          makeRequest("POST", "/question/reply"),
          body: const ReplyToQuestionRequest(
            requestId: "q1",
            sessionId: "",
            answers: [
              ReplyAnswer(values: ["ok"]),
            ],
          ),
          pathParams: {},
          queryParams: {},
          fragment: null,
        ),
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(400))),
      );
    });
  });
}
