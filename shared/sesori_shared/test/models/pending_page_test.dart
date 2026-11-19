import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

Map<String, dynamic> _roundTrip(Map<String, dynamic> json) => jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  const image = PageImage(path: "/fixture/page-images/a.png", width: 640, height: 480, caption: "Fixture caption");
  const page = PendingPage(
    id: "sesori-page-fixture",
    sessionId: "child",
    displaySessionId: "parent",
    title: "Fixture page",
    intro: "Some **Markdown** intro",
    sections: [
      PageSection(
        heading: "First section",
        body: "Section body",
        images: [image],
        questions: [
          PageQuestion(
            id: "q-single",
            title: "Pick one",
            body: null,
            images: [],
            kind: PageQuestionKind.single,
            options: [
              PageOption(id: "a", label: "First", description: "Detail", image: image, recommended: true),
              PageOption(id: "b", label: "Second", description: null, image: null, recommended: false),
            ],
            isRequired: true,
          ),
          PageQuestion(
            id: "q-text",
            title: "Explain",
            body: "Optional context",
            images: [image],
            kind: PageQuestionKind.text,
            options: [],
            isRequired: false,
          ),
        ],
      ),
      PageSection(heading: null, body: null, images: [], questions: []),
    ],
  );
  const answers = [
    PageAnswer(questionId: "q-single", optionIds: ["a"], text: null, note: "Because"),
    PageAnswer(questionId: "q-text", optionIds: [], text: "Fixture answer", note: null),
  ];

  test("a page round trips and omits absent optional text", () {
    final json = _roundTrip(page.toJson());
    expect(PendingPage.fromJson(json), page);
    final sections = json["sections"] as List<dynamic>;
    expect((sections.last as Map<String, dynamic>).containsKey("heading"), isFalse);
  });

  test("a future question kind stays explicitly unknown", () {
    final json = _roundTrip(page.sections.first.questions.first.toJson())..["kind"] = "future";
    expect(PageQuestion.fromJson(json).kind, PageQuestionKind.unknown);
  });

  test("submit requests round trip answers and the page note", () {
    const request = SubmitPageRequest(
      requestId: "sesori-page-fixture",
      sessionId: "child",
      answers: answers,
      note: "Anything else",
    );
    expect(SubmitPageRequest.fromJson(_roundTrip(request.toJson())), request);
    expect(
      SubmitPageRequest.fromJson({"requestId": "r", "sessionId": "s", "answers": <Object>[]}).note,
      isNull,
    );
  });

  test("submit results stay distinct and future variants fall back to unknown", () {
    for (final result in const [
      PageSubmitResult.accepted(),
      PageSubmitResult.alreadySettled(),
      PageSubmitResult.invalid(questionIds: ["q-single"]),
    ]) {
      expect(PageSubmitResult.fromJson(_roundTrip(result.toJson())), result);
    }
    expect(PageSubmitResult.fromJson({"type": "future"}), isA<PageSubmitUnknown>());
  });

  test("lookup requests and responses round trip; future variants fall back to unknown", () {
    const request = PageLookupRequest(sessionId: "parent", requestId: "sesori-page-fixture");
    expect(PageLookupRequest.fromJson(_roundTrip(request.toJson())), request);
    for (final response in const [
      PageLookupResponse.pending(page: page),
      PageLookupResponse.answered(page: page, answers: answers, note: "Anything else"),
      PageLookupResponse.answered(page: page, answers: [], note: null),
      PageLookupResponse.dismissed(page: page),
      PageLookupResponse.missing(),
    ]) {
      expect(PageLookupResponse.fromJson(_roundTrip(response.toJson())), response);
    }
    expect(PageLookupResponse.fromJson({"type": "future"}), isA<PageLookupUnknown>());
  });

  test("text parts carry an optional page reference that older payloads omit", () {
    const withReference = MessagePart.text(
      id: "part",
      sessionID: "parent",
      messageID: "message",
      text: "You answered",
      noticePageRequestId: "sesori-page-fixture",
    );
    expect(MessagePart.fromJson(_roundTrip(withReference.toJson())), withReference);

    final legacy = MessagePart.fromJson({
      "type": "text",
      "id": "part",
      "sessionID": "parent",
      "messageID": "message",
      "text": "Plain text",
    });
    expect(legacy, isA<MessagePartText>().having((p) => p.noticePageRequestId, "reference", isNull));
    expect(legacy.toJson().containsKey("noticePageRequestId"), isFalse);
  });
}
