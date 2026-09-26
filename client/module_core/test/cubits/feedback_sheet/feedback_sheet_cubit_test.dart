import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

class _MockAppReviewClient() extends Mock implements AppReviewClient;

class _MockFeedbackRepository() extends Mock implements FeedbackRepository;

void main() {
  late _MockAppReviewClient appReviewClient;
  late _MockFeedbackRepository feedbackRepository;
  late FakeFeedbackPromptService feedbackPromptService;
  late MockProductAnalyticsService productAnalyticsService;
  late FeedbackSheetCubit cubit;

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(<FeedbackIssue>{});
    registerFallbackValue(FeedbackSource.settings);
  });

  setUp(() {
    appReviewClient = _MockAppReviewClient();
    feedbackRepository = _MockFeedbackRepository();
    feedbackPromptService = FakeFeedbackPromptService();
    productAnalyticsService = stubbedProductAnalyticsService();
    when(appReviewClient.openStoreReviewPage).thenAnswer((_) async {});
    cubit = FeedbackSheetCubit(
      appReviewClient: appReviewClient,
      feedbackRepository: feedbackRepository,
      feedbackPromptService: feedbackPromptService,
      productAnalyticsService: productAnalyticsService,
      source: FeedbackSource.settings,
    );
  });

  tearDown(() => cubit.close());

  void answerSubmit(Future<void> Function() answer) => when(
    () => feedbackRepository.submit(
      issues: any(named: "issues"),
      message: any(named: "message"),
      source: any(named: "source"),
    ),
  ).thenAnswer((_) => answer());

  List<ProductAnalyticsEvent> reportedEvents() => verify(
    () => productAnalyticsService.logEvent(
      event: captureAny(named: "event"),
      occurredAtUtc: any(named: "occurredAtUtc"),
    ),
  ).captured.cast<ProductAnalyticsEvent>();

  test("closing before answering is a dismissal", () {
    expect(cubit.state, const FeedbackSheetState.rating());
    expect(cubit.outcome, isA<FeedbackSheetOutcomeDismissed>());
  });

  test("Yes retires the automatic sheet once, and Could be better does not", () {
    cubit.chooseCouldBeBetter();
    expect(feedbackPromptService.yesAnswers, 0);

    cubit.start();
    cubit.chooseLove();
    cubit.chooseLove();
    expect(feedbackPromptService.yesAnswers, 1);
  });

  test("Yes counts as love from the celebration onward, and Leave a review is recorded", () {
    cubit.chooseLove();
    expect(cubit.state, const FeedbackSheetState.celebrating());
    expect(cubit.outcome, isA<FeedbackSheetOutcomeLoveNotNow>());

    cubit.finishCelebration();
    expect(cubit.state, const FeedbackSheetState.reviewConfirmation());
    expect(cubit.outcome, isA<FeedbackSheetOutcomeLoveNotNow>());

    cubit.chooseLeaveReview();
    expect(cubit.state, const FeedbackSheetState.reviewAccepted());
    expect(cubit.outcome, isA<FeedbackSheetOutcomeLoveLeaveReview>());
  });

  test("an answer is final: repeated or crossed taps keep the first choice", () {
    cubit.chooseLove();
    cubit.chooseCouldBeBetter();
    cubit.chooseLeaveReview();
    expect(cubit.state, const FeedbackSheetState.celebrating());

    cubit.start();
    cubit.chooseCouldBeBetter();
    cubit.chooseLove();
    cubit.finishCelebration();
    expect(cubit.state, isA<FeedbackSheetPrivateFeedback>());
    expect(cubit.outcome, isA<FeedbackSheetOutcomeCouldBeBetter>().having((o) => o.sent, "sent", isFalse));
  });

  test("start resets a finished sheet to the first question", () {
    cubit.chooseLove();
    cubit.finishCelebration();
    cubit.chooseLeaveReview();

    cubit.start();

    expect(cubit.state, const FeedbackSheetState.rating());
    expect(cubit.outcome, isA<FeedbackSheetOutcomeDismissed>());
  });

  test("requestStoreReview from Settings opens the store review page", () async {
    await cubit.requestStoreReview();

    verify(appReviewClient.openStoreReviewPage).called(1);
    verifyNoMoreInteractions(appReviewClient);
  });

  group("automatic sheet", () {
    late FeedbackSheetCubit automatic;

    setUp(() {
      when(appReviewClient.requestReview).thenAnswer((_) async {});
      automatic = FeedbackSheetCubit(
        appReviewClient: appReviewClient,
        feedbackRepository: feedbackRepository,
        feedbackPromptService: feedbackPromptService,
        productAnalyticsService: productAnalyticsService,
        source: FeedbackSource.automatic,
      );
    });

    tearDown(() => automatic.close());

    test("with an in-app OS prompt, the celebration ends without a confirmation and asks the OS", () async {
      when(() => appReviewClient.requestReviewOpensStore).thenReturn(false);
      automatic.chooseLove();
      automatic.finishCelebration();

      expect(automatic.state, const FeedbackSheetState.reviewPromptPending());
      expect(automatic.outcome, isA<FeedbackSheetOutcomeLoveLeaveReview>());

      await automatic.requestStoreReview();
      verify(appReviewClient.requestReview).called(1);
      verifyNever(appReviewClient.openStoreReviewPage);
    });

    test("when the review opens the store, the user confirms first", () async {
      when(() => appReviewClient.requestReviewOpensStore).thenReturn(true);
      automatic.chooseLove();
      automatic.finishCelebration();

      expect(automatic.state, const FeedbackSheetState.reviewConfirmation());
      automatic.chooseLeaveReview();
      expect(automatic.outcome, isA<FeedbackSheetOutcomeLoveLeaveReview>());

      await automatic.requestStoreReview();
      verify(appReviewClient.requestReview).called(1);
      verifyNever(appReviewClient.openStoreReviewPage);
    });
  });

  test("issues toggle, and Send submits them with the message and source", () async {
    answerSubmit(() async {});
    cubit.chooseCouldBeBetter();
    cubit.toggleIssue(issue: FeedbackIssue.appSlow);
    cubit.toggleIssue(issue: FeedbackIssue.connectionDrops);
    cubit.toggleIssue(issue: FeedbackIssue.appSlow);

    await cubit.submit(message: "Fixture feedback", inputMode: ComposerInputMode.typed);

    verify(
      () => feedbackRepository.submit(
        issues: {FeedbackIssue.connectionDrops},
        message: "Fixture feedback",
        source: FeedbackSource.settings,
      ),
    ).called(1);
    expect(
      cubit.state,
      const FeedbackSheetState.privateFeedback(
        issues: {FeedbackIssue.connectionDrops},
        submission: FeedbackSubmission.sent,
      ),
    );
    expect(cubit.outcome, isA<FeedbackSheetOutcomeCouldBeBetter>().having((o) => o.sent, "sent", isTrue));
  });

  test("a failed send keeps the issues and allows a retry", () async {
    answerSubmit(() async => throw StateError("offline"));
    cubit.chooseCouldBeBetter();
    cubit.toggleIssue(issue: FeedbackIssue.hardToNavigate);

    await cubit.submit(message: "Fixture feedback", inputMode: ComposerInputMode.typed);
    expect(
      cubit.state,
      const FeedbackSheetState.privateFeedback(
        issues: {FeedbackIssue.hardToNavigate},
        submission: FeedbackSubmission.failed,
      ),
    );

    answerSubmit(() async {});
    await cubit.submit(message: "Fixture feedback", inputMode: ComposerInputMode.typed);
    expect((cubit.state as FeedbackSheetPrivateFeedback).submission, FeedbackSubmission.sent);
  });

  test("a send in flight locks the issues and ignores a second Send", () async {
    final pending = Completer<void>();
    answerSubmit(() => pending.future);
    cubit.chooseCouldBeBetter();

    final first = cubit.submit(message: "Fixture feedback", inputMode: ComposerInputMode.typed);
    expect((cubit.state as FeedbackSheetPrivateFeedback).submission, FeedbackSubmission.submitting);
    cubit.toggleIssue(issue: FeedbackIssue.appSlow);
    await cubit.submit(message: "Fixture feedback", inputMode: ComposerInputMode.typed);
    expect((cubit.state as FeedbackSheetPrivateFeedback).issues, isEmpty);

    pending.complete();
    await first;
    verify(
      () => feedbackRepository.submit(
        issues: any(named: "issues"),
        message: any(named: "message"),
        source: any(named: "source"),
      ),
    ).called(1);
  });

  test("a send that finishes after the sheet was reopened leaves the new sheet alone", () async {
    final pending = Completer<void>();
    answerSubmit(() => pending.future);
    cubit.chooseCouldBeBetter();
    final send = cubit.submit(message: "Fixture feedback", inputMode: ComposerInputMode.typed);

    cubit.start();
    pending.complete();
    await send;

    expect(cubit.state, const FeedbackSheetState.rating());
  });

  test("finish reports the answer the sheet ended with and its source", () {
    expect(cubit.finish(), isA<FeedbackSheetOutcomeDismissed>());

    cubit.start();
    cubit.chooseLove();
    cubit.finish();

    cubit.start();
    cubit.chooseLove();
    cubit.finishCelebration();
    cubit.chooseLeaveReview();
    cubit.finish();

    cubit.start();
    cubit.chooseCouldBeBetter();
    cubit.finish();

    expect(reportedEvents(), [
      for (final answer in [
        AnalyticsFeedbackAnswer.dismissed,
        AnalyticsFeedbackAnswer.loveNoReview,
        AnalyticsFeedbackAnswer.loveReviewRequested,
        AnalyticsFeedbackAnswer.couldBeBetter,
      ])
        ProductAnalyticsEvent.feedbackPromptAnswered(answer: answer, source: AnalyticsFeedbackSource.settings),
    ]);
  });

  test("private feedback is reported once the server accepts it, with what it carried", () async {
    Future<void> send({
      required Set<FeedbackIssue> issues,
      required String message,
      required ComposerInputMode inputMode,
    }) async {
      cubit.start();
      cubit.chooseCouldBeBetter();
      for (final issue in issues) {
        cubit.toggleIssue(issue: issue);
      }
      await cubit.submit(message: message, inputMode: inputMode);
    }

    answerSubmit(() async => throw StateError("offline"));
    await send(issues: {}, message: "Fixture feedback", inputMode: ComposerInputMode.typed);
    verifyNever(
      () => productAnalyticsService.logEvent(
        event: any(named: "event"),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    );

    answerSubmit(() async {});
    await send(issues: {}, message: "Fixture feedback", inputMode: ComposerInputMode.typed);
    await send(issues: {}, message: "Fixture feedback", inputMode: ComposerInputMode.voiceAssisted);
    await send(issues: {FeedbackIssue.appSlow}, message: "  ", inputMode: ComposerInputMode.voiceAssisted);
    await send(issues: {}, message: "", inputMode: ComposerInputMode.typed);

    expect(reportedEvents(), [
      for (final input in [
        AnalyticsFeedbackInput.typed,
        AnalyticsFeedbackInput.voiceAssisted,
        AnalyticsFeedbackInput.issuesOnly,
        AnalyticsFeedbackInput.empty,
      ])
        ProductAnalyticsEvent.privateFeedbackSent(input: input, source: AnalyticsFeedbackSource.settings),
    ]);
  });
}
