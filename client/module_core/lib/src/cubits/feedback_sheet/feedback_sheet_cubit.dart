import "package:bloc/bloc.dart";

import "../../platform/app_review_client.dart";
import "feedback_sheet_outcome.dart";
import "feedback_sheet_state.dart";

/// Drives one rating sheet from its first question to its outcome.
class FeedbackSheetCubit({required final AppReviewClient _appReviewClient}) extends Cubit<FeedbackSheetState> {
  this : super(const FeedbackSheetState.rating());

  /// Resets to the first question; every presentation starts fresh.
  void start() => emit(const FeedbackSheetState.rating());

  void chooseLove() {
    if (state is! FeedbackSheetRating) return;
    emit(const FeedbackSheetState.celebrating());
  }

  void finishCelebration() {
    if (state is! FeedbackSheetCelebrating) return;
    emit(const FeedbackSheetState.reviewConfirmation());
  }

  void chooseLeaveReview() {
    if (state is! FeedbackSheetReviewConfirmation) return;
    emit(const FeedbackSheetState.reviewAccepted());
  }

  void chooseCouldBeBetter() {
    if (state is! FeedbackSheetRating) return;
    emit(const FeedbackSheetState.couldBeBetter());
  }

  /// The answer this sheet ended with, read once its route has closed.
  FeedbackSheetOutcome get outcome => switch (state) {
    FeedbackSheetRating() => const FeedbackSheetOutcomeDismissed(),
    FeedbackSheetCelebrating() ||
    FeedbackSheetReviewConfirmation() => const FeedbackSheetOutcomeLove(leaveReview: false),
    FeedbackSheetReviewAccepted() => const FeedbackSheetOutcomeLove(leaveReview: true),
    FeedbackSheetCouldBeBetter() => const FeedbackSheetOutcomeCouldBeBetter(),
  };

  /// Opens the store review page. Call only after the sheet's route has
  /// finished closing, so leaving the app never cuts its exit short.
  Future<void> requestStoreReview() => _appReviewClient.openStoreReviewPage();
}
