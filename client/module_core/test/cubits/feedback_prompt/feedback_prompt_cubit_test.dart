import "package:bloc_test/bloc_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

/// Answers like iOS when [allowsQuestionBeforeReview], like Android otherwise.
class _FakeAppReviewClient({@override required final bool allowsQuestionBeforeReview}) implements AppReviewClient {
  int reviewRequests = 0;
  int storePagesOpened = 0;

  @override
  Future<void> requestReview() async => reviewRequests++;

  @override
  Future<void> openStoreReviewPage() async => storePagesOpened++;
}

void main() {
  late FakeFeedbackPromptService feedbackPromptService;
  late MockProductAnalyticsService productAnalyticsService;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    feedbackPromptService = FakeFeedbackPromptService();
    productAnalyticsService = stubbedProductAnalyticsService();
  });

  tearDown(() => feedbackPromptService.promptsController.close());

  FeedbackPromptCubit build({required AppReviewClient appReviewClient}) => FeedbackPromptCubit(
    feedbackPromptService: feedbackPromptService,
    appReviewClient: appReviewClient,
    productAnalyticsService: productAnalyticsService,
  );

  group("where Sesori may ask first, as on iOS", () {
    late _FakeAppReviewClient appReviewClient;

    setUp(() => appReviewClient = _FakeAppReviewClient(allowsQuestionBeforeReview: true));

    blocTest<FeedbackPromptCubit, FeedbackPromptPresentation>(
      "asks to show the sheet once per claimed showing, each a distinct state, without requesting a review",
      build: () => build(appReviewClient: appReviewClient),
      act: (_) {
        feedbackPromptService.promptsController
          ..add(null)
          ..add(null);
      },
      expect: () => const [
        FeedbackPromptPresentation.show(sequence: 1),
        FeedbackPromptPresentation.show(sequence: 2),
      ],
      verify: (_) {
        expect(appReviewClient.reviewRequests, 0);
        verifyNever(
          () => productAnalyticsService.logEvent(
            event: any(named: "event"),
            occurredAtUtc: any(named: "occurredAtUtc"),
          ),
        );
      },
    );
  });

  group("where Sesori may not ask first, as on Android", () {
    late _FakeAppReviewClient appReviewClient;

    setUp(() => appReviewClient = _FakeAppReviewClient(allowsQuestionBeforeReview: false));

    blocTest<FeedbackPromptCubit, FeedbackPromptPresentation>(
      "requests the in-app review directly, with no sheet and no store hand-off, and reports the request",
      build: () => build(appReviewClient: appReviewClient),
      act: (_) => feedbackPromptService.promptsController.add(null),
      expect: () => const <FeedbackPromptPresentation>[],
      verify: (_) {
        expect(appReviewClient.reviewRequests, 1);
        expect(appReviewClient.storePagesOpened, 0);
        verify(
          () => productAnalyticsService.logEvent(
            event: const ProductAnalyticsEvent.feedbackPromptAnswered(
              answer: AnalyticsFeedbackAnswer.loveReviewRequested,
              source: AnalyticsFeedbackSource.automatic,
            ),
            occurredAtUtc: any(named: "occurredAtUtc"),
          ),
        ).called(1);
      },
    );
  });

  test("starts idle and stops listening once closed", () async {
    final cubit = build(appReviewClient: _FakeAppReviewClient(allowsQuestionBeforeReview: true));
    expect(cubit.state, const FeedbackPromptPresentation.idle());

    await cubit.close();

    expect(feedbackPromptService.promptsController.hasListener, isFalse);
  });
}
