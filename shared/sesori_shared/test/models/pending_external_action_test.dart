import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const action = PendingExternalAction(
    id: "request",
    sessionID: "child",
    displaySessionId: "parent",
    title: "Fixture server",
    message: "Continue the native authorization request.",
    authorizationUrl: "https://fixture.example/authorize?state=private-fixture",
    purpose: ExternalActionPurpose.authorization,
    choices: [ExternalActionChoice.accept, ExternalActionChoice.decline, ExternalActionChoice.cancel],
  );

  test("snapshots preserve the native reply owner, display parent and declared choices", () {
    const response = PendingExternalActionsResponse(data: [action]);
    final decoded = PendingExternalActionsResponse.fromJson(response.toJson());
    expect(decoded.data.single, action);
    expect(decoded.data.single.sessionID, "child");
    expect(decoded.data.single.displaySessionId, "parent");
    expect(
      decoded.data.single.choices,
      ExternalActionChoice.values.where((choice) => choice != ExternalActionChoice.unknown),
    );
    expect(action.toString(), isNot(contains("private-fixture")));
    expect(response.toString(), isNot(contains("private-fixture")));
  });

  test("future purposes and choices remain unknown instead of gaining consent", () {
    final decoded = PendingExternalAction.fromJson(
      action.toJson()
        ..["purpose"] = "future"
        ..["choices"] = ["future", "decline"],
    );
    expect(decoded.purpose, ExternalActionPurpose.unknown);
    expect(decoded.choices, [ExternalActionChoice.unknown, ExternalActionChoice.decline]);
    expect(
      ReplyToExternalActionRequest.fromJson({"requestId": "request", "sessionId": "child", "choice": "future"}).choice,
      ExternalActionChoice.unknown,
    );
  });

  test("replies retain scalar native choices and distinguish settlement outcomes", () {
    for (final choice in [ExternalActionChoice.accept, ExternalActionChoice.decline, ExternalActionChoice.cancel]) {
      final request = ReplyToExternalActionRequest(requestId: "request", sessionId: "child", choice: choice);
      expect(ReplyToExternalActionRequest.fromJson(request.toJson()), request);
      expect(request.toJson()["choice"], choice.name);
    }
    for (final result in [
      const ExternalActionReplyAccepted(),
      const ExternalActionAlreadySettled(),
      const ExternalActionUnsupportedChoice(),
    ]) {
      expect(ExternalActionReplyResult.fromJson(result.toJson()), result);
    }
    expect(ExternalActionReplyResult.fromJson({"type": "future"}), const ExternalActionReplyUnknown());
    expect(const ExternalActionReplyAccepted().toJson().containsKey("connected"), isFalse);
  });

  test("released question snapshots and events without a marker remain ordinary questions", () {
    final json = <String, dynamic>{
      "id": "request",
      "sessionID": "child",
      "displaySessionId": "parent",
      "questions": [
        {"question": "Fixture question", "header": "Question", "options": <Object>[]},
      ],
    };
    expect(PendingQuestion.fromJson(json).interactionKind, QuestionInteractionKind.question);
    final event = SesoriSseEvent.fromJson({...json, "type": "question.asked"});
    expect(
      event,
      isA<SesoriQuestionAsked>().having((e) => e.interactionKind, "kind", QuestionInteractionKind.question),
    );
  });

  test("marked notices preserve attribution without becoming ordinary questions", () {
    for (final kind in [QuestionInteractionKind.form, QuestionInteractionKind.externalAction]) {
      final json = <String, dynamic>{
        "id": "request",
        "sessionID": "child",
        "displaySessionId": "parent",
        "interactionKind": kind.name,
        "questions": [
          {
            "question": "Use an updated Sesori client to answer this request, or cancel it here.",
            "header": "Update required",
            "custom": false,
            "options": [
              {"label": "Cancel", "description": "Cancel this native request."},
            ],
          },
        ],
      };
      final snapshot = PendingQuestion.fromJson(json);
      final event = SesoriSseEvent.fromJson({...json, "type": "question.asked"});
      expect(snapshot.interactionKind, kind);
      expect(snapshot.questions.single.custom, isFalse);
      expect(event, isA<SesoriQuestionAsked>().having((e) => e.interactionKind, "kind", kind));
      expect(SesoriSseEvent.fromJson(event.toJson()), event);
      expect(event.toJson().containsKey("authorizationUrl"), isFalse);
    }
    expect(
      PendingQuestion.fromJson({
        "id": "request",
        "sessionID": "child",
        "questions": <Object>[],
        "interactionKind": "future",
      }).interactionKind,
      QuestionInteractionKind.unknown,
    );
  });
}
