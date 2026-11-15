import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

Map<String, dynamic> _roundTripJson(Object value) => jsonDecodeMap(jsonEncode(value));

void main() {
  const exchange = SideChatExchange(
    id: "sqx_1",
    question: "what is this?",
    answer: "a side answer",
    answerNotice: null,
    askedAt: 100,
    answeredAt: 200,
  );

  test("an exchange omits a missing notice and reads it back as null", () {
    final json = _roundTripJson(exchange.toJson());

    expect(json.containsKey("answerNotice"), isFalse);
    expect(SideChatExchange.fromJson(json), exchange);
  });

  test("the side chat list round-trips", () {
    const response = SideChatListResponse(
      sideChats: [
        SideChat(id: "sqc_1", exchanges: [exchange]),
      ],
    );

    expect(SideChatListResponse.fromJson(_roundTripJson(response.toJson())), response);
  });

  test("an ask request without a side chat id starts a new chat", () {
    final request = AskSideQuestionRequest.fromJson(const {"sessionId": "s-1", "question": "q"});

    expect(request.sideChatId, isNull);
    expect(request.toJson().containsKey("sideChatId"), isFalse);
  });

  test("answered and refused responses round-trip with their type", () {
    const answered = AskSideQuestionResponse.answered(sideChatId: "sqc_1", exchange: exchange);
    const refused = AskSideQuestionResponse.refused(reason: SideQuestionRefusal.tooLong);

    final answeredJson = _roundTripJson(answered.toJson());
    final refusedJson = _roundTripJson(refused.toJson());

    expect(answeredJson["type"], "answered");
    expect(refusedJson, {"type": "refused", "reason": "tooLong"});
    expect(AskSideQuestionResponse.fromJson(answeredJson), answered);
    expect(AskSideQuestionResponse.fromJson(refusedJson), refused);
  });

  test("a newer bridge's response type and refusal read as unknown", () {
    expect(
      AskSideQuestionResponse.fromJson(const {"type": "streaming", "chunk": "x"}),
      isA<AskSideQuestionUnknown>(),
    );
    expect(
      AskSideQuestionResponse.fromJson(const {"type": "refused", "reason": "quotaExceeded"}),
      isA<AskSideQuestionRefused>().having((r) => r.reason, "reason", SideQuestionRefusal.unknown),
    );
  });

  test("plugin capabilities default an omitted side-question flag to false", () {
    final response = PluginListResponse.fromJson(const {
      "bridgeId": null,
      "plugins": [
        {"id": "claude", "displayName": "Claude Code", "isDefault": true, "state": "ready"},
      ],
    });

    expect(response.supportsSideQuestions, isFalse);
    expect(response.plugins.single.supportsSideQuestions, isFalse);
  });

  test("plugin capabilities round-trip the side-question flags", () {
    const response = PluginListResponse(
      bridgeId: null,
      supportsSideQuestions: true,
      plugins: [
        PluginMetadata(
          id: "claude",
          displayName: "Claude Code",
          isDefault: true,
          state: PluginLifecycleState.ready,
          actionHint: null,
          failureBlock: null,
          mcpScopes: null,
          failureReason: null,
          supportsSideQuestions: true,
        ),
      ],
    );

    final decoded = PluginListResponse.fromJson(_roundTripJson(response.toJson()));

    expect(decoded.supportsSideQuestions, isTrue);
    expect(decoded.plugins.single.supportsSideQuestions, isTrue);
  });
}
