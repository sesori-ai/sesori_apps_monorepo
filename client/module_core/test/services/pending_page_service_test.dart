import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

const pageImage = PageImage(path: "/pages/owner/diagram.png", width: 640, height: 480, caption: null);

/// A page whose sub-agent session `owner` differs from its root `root`.
const page = PendingPage(
  id: "sesori-page-1",
  sessionId: "owner",
  displaySessionId: "root",
  title: "Pick a plan",
  intro: null,
  sections: [
    PageSection(
      heading: "Plan",
      body: null,
      images: [],
      questions: [
        PageQuestion(
          id: "plan",
          title: "Which plan?",
          body: null,
          images: [],
          kind: PageSingleChoice(
            options: [
              PageOption(id: "a", label: "A", description: null, image: pageImage, recommended: true),
              PageOption(id: "b", label: "B", description: null, image: null, recommended: false),
            ],
          ),
          isRequired: true,
        ),
        PageQuestion(
          id: "extras",
          title: "Extras?",
          body: null,
          images: [],
          kind: PageMultipleChoice(
            options: [
              PageOption(id: "x", label: "X", description: null, image: null, recommended: false),
              PageOption(id: "y", label: "Y", description: null, image: null, recommended: false),
            ],
          ),
          isRequired: false,
        ),
      ],
    ),
    PageSection(
      heading: null,
      body: "Anything to add?",
      images: [],
      questions: [
        PageQuestion(id: "why", title: "Why?", body: null, images: [], kind: PageTextInput(), isRequired: true),
      ],
    ),
  ],
);

final answeredDraft = PageDraft.empty
    .withText(questionId: "why", text: "Faster")
    .withChoice(questionId: "plan", optionId: "a")
    .withNote(note: "Thanks");

void main() {
  setUpAll(registerAllFallbackValues);
  late MockSessionRepository repository;
  late MockProductAnalyticsService analytics;
  late PendingPageService service;
  setUp(() {
    repository = MockSessionRepository();
    analytics = stubbedProductAnalyticsService();
    service = PendingPageService(repository: repository, productAnalyticsService: analytics);
    registerFallbackValue(const SubmitPageRequest(requestId: "r", sessionId: "s", answers: [], note: null));
    registerFallbackValue(const PageLookupRequest(sessionId: "s", requestId: "r"));
  });

  List<ProductAnalyticsEvent> reported() => verify(
    () => analytics.logEvent(
      event: captureAny(named: "event"),
      occurredAtUtc: any(named: "occurredAtUtc"),
    ),
  ).captured.cast<ProductAnalyticsEvent>();

  void expectNothingReported() => verifyNever(
    () => analytics.logEvent(
      event: any(named: "event"),
      occurredAtUtc: any(named: "occurredAtUtc"),
    ),
  );

  test("lookup asks for the request under the given session and throws a failed request", () async {
    when(() => repository.lookupPage(request: any(named: "request")))
        .thenAnswer((_) async => ApiResponse.success(const PageLookupResponse.pending(page: page)));
    expect(await service.lookup(requestId: page.id, sessionId: "root"), const PageLookupPending(page: page));
    verify(
      () => repository.lookupPage(
        request: const PageLookupRequest(sessionId: "root", requestId: "sesori-page-1"),
      ),
    ).called(1);

    when(() => repository.lookupPage(request: any(named: "request")))
        .thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
    await expectLater(service.lookup(requestId: page.id, sessionId: "root"), throwsA(isA<ApiError>()));
  });

  test("required questions answered by a note alone or not at all refuse locally", () async {
    final draft = PageDraft.empty
        .withQuestionNote(questionId: "plan", note: "Not sure")
        .withChoices(questionId: "extras", optionIds: ["x"]);
    expect(service.unansweredRequired(page: page, draft: draft), ["plan", "why"]);

    expect(await service.submit(page: page, draft: draft), const PageSubmitInvalid(questionIds: ["plan", "why"]));
    verifyNever(() => repository.submitPage(request: any(named: "request")));
    expectNothingReported();
  });

  test("an accepted submit sends answers in page order and reports one answered outcome", () async {
    when(() => repository.submitPage(request: any(named: "request")))
        .thenAnswer((_) async => ApiResponse.success(const PageSubmitResult.accepted()));

    expect(await service.submit(page: page, draft: answeredDraft), const PageSubmitAccepted());

    verify(
      () => repository.submitPage(
        request: const SubmitPageRequest(
          requestId: "sesori-page-1",
          sessionId: "owner",
          answers: [
            PageAnswer(
              questionId: "plan",
              value: PageChoiceAnswer(optionId: "a"),
              note: null,
            ),
            PageAnswer(
              questionId: "why",
              value: PageTextAnswer(text: "Faster"),
              note: null,
            ),
          ],
          note: "Thanks",
        ),
      ),
    ).called(1);
    final events = reported();
    expect(events, hasLength(1));
    expect(events.single.wireName, "question_page_finished");
    expect(events.single.parameters, {"outcome": "answered", "question_count": "2_5", "has_images": "true"});
  });

  for (final result in [
    const PageSubmitResult.alreadySettled(),
    const PageSubmitResult.invalid(questionIds: ["plan"]),
    const PageSubmitResult.unknown(),
  ]) {
    test("a ${result.runtimeType} submit reports nothing", () async {
      when(() => repository.submitPage(request: any(named: "request")))
          .thenAnswer((_) async => ApiResponse.success(result));
      expect(await service.submit(page: page, draft: answeredDraft), result);
      expectNothingReported();
    });
  }

  test("a failed submit throws and reports nothing", () async {
    when(() => repository.submitPage(request: any(named: "request")))
        .thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
    await expectLater(service.submit(page: page, draft: answeredDraft), throwsA(isA<ApiError>()));
    expectNothingReported();
  });

  test("a confirmed dismiss rejects under the page's own session and reports it", () async {
    when(() => repository.rejectQuestion(requestId: page.id, sessionId: "owner"))
        .thenAnswer((_) async => ApiResponse.success(null));
    await service.dismiss(page: page);
    expect(reported().single.parameters, {"outcome": "dismissed", "question_count": "2_5", "has_images": "true"});
  });

  test("a failed dismiss throws and reports nothing", () async {
    when(() => repository.rejectQuestion(requestId: page.id, sessionId: "owner"))
        .thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
    await expectLater(service.dismiss(page: page), throwsA(isA<ApiError>()));
    expectNothingReported();
  });

  test("an informative page counts no questions and no images", () {
    const informative = PendingPage(
      id: "sesori-page-2",
      sessionId: "owner",
      displaySessionId: null,
      title: "Done",
      intro: "All set.",
      sections: [],
    );
    expect(
      QuestionPageFinishedEvent.of(outcome: AnalyticsQuestionPageOutcome.answered, page: informative).parameters,
      {"outcome": "answered", "question_count": "0", "has_images": "false"},
    );
  });

  test("a required question of a kind this app doesn't know never blocks Submit", () {
    const newer = PendingPage(
      id: "sesori-page-3",
      sessionId: "owner",
      displaySessionId: null,
      title: "Rate it",
      intro: null,
      sections: [
        PageSection(
          heading: null,
          body: null,
          images: [],
          questions: [
            PageQuestion(
              id: "stars",
              title: "Stars?",
              body: null,
              images: [],
              kind: PageQuestionKindUnknown(),
              isRequired: true,
            ),
          ],
        ),
      ],
    );
    expect(service.unansweredRequired(page: newer, draft: PageDraft.empty), isEmpty);
  });
}
