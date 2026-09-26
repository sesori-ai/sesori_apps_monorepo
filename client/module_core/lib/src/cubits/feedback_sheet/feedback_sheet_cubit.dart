import "dart:async";

import "package:bloc/bloc.dart";

import "../../foundation/models/feedback/feedback_issue.dart";
import "../../foundation/models/feedback/feedback_source.dart";
import "../../logging/logging.dart";
import "../../platform/app_review_client.dart";
import "../../repositories/feedback_repository.dart";
import "../../services/feedback_prompt_service.dart";
import "feedback_sheet_outcome.dart";
import "feedback_sheet_state.dart";

/// Drives one rating sheet from its first question to its outcome.
class FeedbackSheetCubit({
  required final AppReviewClient _appReviewClient,
  required final FeedbackRepository _feedbackRepository,
  required final FeedbackPromptService _feedbackPromptService,
  required final FeedbackSource _source,
}) extends Cubit<FeedbackSheetState> {
  this : super(const FeedbackSheetState.rating());

  /// Resets to the first question; every presentation starts fresh.
  void start() => emit(const FeedbackSheetState.rating());

  /// **Yes, love it!** from either entry also retires the automatic sheet.
  void chooseLove() {
    if (state is! FeedbackSheetRating) return;
    emit(const FeedbackSheetState.celebrating());
    unawaited(_feedbackPromptService.recordYes());
  }

  void finishCelebration() {
    if (state is! FeedbackSheetCelebrating) return;
    emit(
      _reviewLeavesApp ? const FeedbackSheetState.reviewConfirmation() : const FeedbackSheetState.reviewPromptPending(),
    );
  }

  void chooseLeaveReview() {
    if (state is! FeedbackSheetReviewConfirmation) return;
    emit(const FeedbackSheetState.reviewAccepted());
  }

  void chooseCouldBeBetter() {
    if (state is! FeedbackSheetRating) return;
    emit(const FeedbackSheetState.privateFeedback(issues: {}, submission: FeedbackSubmission.editing));
  }

  void toggleIssue({required FeedbackIssue issue}) {
    final current = state;
    if (current is! FeedbackSheetPrivateFeedback || !current.submission.canEdit) return;
    final issues = current.issues.contains(issue) ? current.issues.difference({issue}) : current.issues.union({issue});
    emit(current.copyWith(issues: issues));
  }

  /// Sends the ticked issues and [message]. A failure keeps the sheet open
  /// with its draft so the user can retry.
  Future<void> submit({required String message}) async {
    final current = state;
    if (current is! FeedbackSheetPrivateFeedback || !current.submission.canEdit) return;
    final submitting = current.copyWith(submission: FeedbackSubmission.submitting);
    emit(submitting);
    FeedbackSubmission result;
    try {
      await _feedbackRepository.submit(issues: current.issues, message: message, source: _source);
      result = FeedbackSubmission.sent;
    } catch (error, stackTrace) {
      // The message may hold pasted code or secrets, so it is never logged.
      logw("Failed to send feedback", error, stackTrace);
      result = FeedbackSubmission.failed;
    }
    // The sheet may have been closed and reopened while this was in flight.
    if (isClosed || !identical(state, submitting)) return;
    emit(submitting.copyWith(submission: result));
  }

  /// The answer this sheet ended with, read once its route has closed.
  FeedbackSheetOutcome get outcome => switch (state) {
    FeedbackSheetRating() => const FeedbackSheetOutcomeDismissed(),
    FeedbackSheetCelebrating() || FeedbackSheetReviewConfirmation() => const FeedbackSheetOutcomeLoveNotNow(),
    FeedbackSheetReviewAccepted() || FeedbackSheetReviewPromptPending() => const FeedbackSheetOutcomeLoveLeaveReview(),
    FeedbackSheetPrivateFeedback(:final submission) => FeedbackSheetOutcomeCouldBeBetter(
      sent: submission == FeedbackSubmission.sent,
    ),
  };

  /// Asks for a review: the OS review prompt for the automatic sheet, the
  /// store review page from Settings. Call only after the sheet's route has
  /// finished closing, so neither cuts its exit short.
  Future<void> requestStoreReview() => switch (_source) {
    FeedbackSource.automatic => _appReviewClient.requestReview(),
    FeedbackSource.settings => _appReviewClient.openStoreReviewPage(),
  };

  /// Whether the review leaves Sesori for the store, which the user confirms
  /// first so leaving the app is never a surprise.
  bool get _reviewLeavesApp => switch (_source) {
    FeedbackSource.automatic => _appReviewClient.requestReviewOpensStore,
    FeedbackSource.settings => true,
  };
}
