import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class _MockAppReviewClient() extends Mock implements AppReviewClient;

void main() {
  late _MockAppReviewClient appReviewClient;
  late FeedbackSheetCubit cubit;

  setUp(() {
    appReviewClient = _MockAppReviewClient();
    when(appReviewClient.openStoreReviewPage).thenAnswer((_) async {});
    cubit = FeedbackSheetCubit(appReviewClient: appReviewClient);
  });

  tearDown(() => cubit.close());

  test("closing before answering is a dismissal", () {
    expect(cubit.state, const FeedbackSheetState.rating());
    expect(cubit.outcome, isA<FeedbackSheetOutcomeDismissed>());
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
    expect(cubit.state, const FeedbackSheetState.couldBeBetter());
    expect(cubit.outcome, isA<FeedbackSheetOutcomeCouldBeBetter>());
  });

  test("start resets a finished sheet to the first question", () {
    cubit.chooseLove();
    cubit.finishCelebration();
    cubit.chooseLeaveReview();

    cubit.start();

    expect(cubit.state, const FeedbackSheetState.rating());
    expect(cubit.outcome, isA<FeedbackSheetOutcomeDismissed>());
  });

  test("requestStoreReview opens the store review page", () async {
    await cubit.requestStoreReview();

    verify(appReviewClient.openStoreReviewPage).called(1);
  });
}
