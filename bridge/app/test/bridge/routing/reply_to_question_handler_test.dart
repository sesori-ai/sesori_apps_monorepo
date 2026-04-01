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

    test("canHandle POST /question/reply", () {
      expect(handler.canHandle(makeRequest("POST", "/question/reply")), isTrue);
    });

    test("extracts requestId, sessionId, and parses answers", () async {
      await handler.handleInternal(
        makeRequest(
          "POST",
          "/question/reply",
          body: jsonEncode(
            const ReplyToQuestionRequest(
              requestId: "q1",
              sessionId: "ses-1",
              answers: [
                ReplyAnswer(values: ["yes"]),
                ReplyAnswer(values: ["tool-a", "tool-b"]),
              ],
            ).toJson(),
          ),
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
      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/question/reply",
          body: jsonEncode(
            const ReplyToQuestionRequest(
              requestId: "q1",
              sessionId: "ses-1",
              answers: [
                ReplyAnswer(values: ["ok"]),
              ],
            ).toJson(),
          ),
        ),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(200));
      expect(response.body, equals("{}"));
    });

    test("returns 400 on missing answers", () async {
      final response = await handler.handleInternal(
        makeRequest("POST", "/question/reply", body: "{}"),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );

      expect(response.status, equals(400));
    });
  });
}
