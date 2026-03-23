import "dart:convert";

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

    test("canHandle POST /question/:id/reply", () {
      expect(handler.canHandle(makeRequest("POST", "/question/q1/reply")), isTrue);
    });

    test("extracts id, sessionId, and parses answers", () async {
      await handler.handle(
        makeRequest(
          "POST",
          "/question/q1/reply",
          body: jsonEncode(
            const ReplyToQuestionRequest(
              sessionId: "ses-1",
              answers: [
                ReplyAnswer(values: ["yes"]),
                ReplyAnswer(values: ["tool-a", "tool-b"]),
              ],
            ).toJson(),
          ),
        ),
        pathParams: {"id": "q1"},
        queryParams: {},
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
        makeRequest(
          "POST",
          "/question/q1/reply",
          body: jsonEncode(
            const ReplyToQuestionRequest(
              sessionId: "ses-1",
              answers: [
                ReplyAnswer(values: ["ok"]),
              ],
            ).toJson(),
          ),
        ),
        pathParams: {"id": "q1"},
        queryParams: {},
      );

      expect(response.status, equals(200));
      expect(response.body, isNull);
    });

    test("returns 400 on missing answers", () async {
      final response = await handler.handle(
        makeRequest("POST", "/question/q1/reply", body: "{}"),
        pathParams: {"id": "q1"},
        queryParams: {},
      );

      expect(response.status, equals(400));
    });

    test("returns 400 when path param id is missing", () async {
      final response = await handler.handle(
        makeRequest(
          "POST",
          "/question/q1/reply",
          body: jsonEncode(
            const ReplyToQuestionRequest(
              sessionId: "ses-1",
              answers: [
                ReplyAnswer(values: ["ok"]),
              ],
            ).toJson(),
          ),
        ),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("missing question id"));
    });
  });
}
