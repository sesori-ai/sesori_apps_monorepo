import "dart:async";

import "package:bloc/bloc.dart";

import "../../foundation/models/composer/composer_draft.dart";
import "../../foundation/models/feedback/feedback_issue.dart";
import "../../foundation/models/feedback/feedback_source.dart";
import "../../foundation/models/product_analytics/product_analytics_event.dart";
import "../../logging/logging.dart";
import "../../platform/app_review_client.dart";
import "../../repositories/feedback_repository.dart";
import "../../repositories/models/analytics_delivery_result.dart";
import "../../services/feedback_prompt_service.dart";
import "../../services/product_analytics_service.dart";
import "feedback_sheet_outcome.dart";
import "feedback_sheet_state.dart";

/// Drives one rating sheet from its first question to its outcome.
class FeedbackSheetCubit({
  required final AppReviewClient _appReviewClient,
  required final FeedbackRepository _feedbackRepository,
  required final FeedbackPromptService _feedbackPromptService,
  required final ProductAnalyticsService _productAnalyticsService,
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

  /// Sends the ticked issues and [message]. [inputMode] says whether a
  /// dictated transcript went into the message. A failure keeps the sheet
  /// open with its draft so the user can retry.
  Future<void> submit({required String message, required ComposerInputMode inputMode}) async {
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
    if (result == FeedbackSubmission.sent) {
      _reportEvent(
        event: ProductAnalyticsEvent.privateFeedbackSent(
          input: switch ((message.trim().isEmpty, inputMode)) {
            (false, ComposerInputMode.typed) => AnalyticsFeedbackInput.typed,
            (false, ComposerInputMode.voiceAssisted) => AnalyticsFeedbackInput.voiceAssisted,
            (true, _) when current.issues.isNotEmpty => AnalyticsFeedbackInput.issuesOnly,
            (true, _) => AnalyticsFeedbackInput.empty,
          },
          source: _analyticsSource,
        ),
      );
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

  /// Reports and returns [outcome]. Call once per presentation, after the
  /// sheet's route has closed.
  FeedbackSheetOutcome finish() {
    final outcome = this.outcome;
    _reportEvent(
      event: ProductAnalyticsEvent.feedbackPromptAnswered(
        answer: switch (outcome) {
          FeedbackSheetOutcomeLoveLeaveReview() => AnalyticsFeedbackAnswer.loveReviewRequested,
          FeedbackSheetOutcomeLoveNotNow() => AnalyticsFeedbackAnswer.loveNoReview,
          FeedbackSheetOutcomeCouldBeBetter() => AnalyticsFeedbackAnswer.couldBeBetter,
          FeedbackSheetOutcomeDismissed() => AnalyticsFeedbackAnswer.dismissed,
        },
        source: _analyticsSource,
      ),
    );
    return outcome;
  }

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

  AnalyticsFeedbackSource get _analyticsSource => switch (_source) {
    FeedbackSource.automatic => AnalyticsFeedbackSource.automatic,
    FeedbackSource.settings => AnalyticsFeedbackSource.settings,
  };

  void _reportEvent({required ProductAnalyticsEvent event}) {
    unawaited(
      _productAnalyticsService
          .logEvent(event: event, occurredAtUtc: DateTime.now().toUtc())
          .then<void>((result) {
            if (result == AnalyticsDeliveryResult.failed && _productAnalyticsService.state.isActive) {
              logw("Failed to deliver feedback analytics event");
            }
          })
          .catchError((Object error, StackTrace stackTrace) {
            logw("Failed to report feedback analytics event", error, stackTrace);
          }),
    );
  }
}
