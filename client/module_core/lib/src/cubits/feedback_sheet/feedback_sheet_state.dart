import "package:freezed_annotation/freezed_annotation.dart";

import "../../foundation/models/feedback/feedback_issue.dart";

part "feedback_sheet_state.freezed.dart";

/// The step one rating sheet is on.
@Freezed()
sealed class FeedbackSheetState with _$FeedbackSheetState {
  /// "Are you enjoying Sesori?" with both answers available.
  const factory rating() = FeedbackSheetRating;

  /// The user answered **Yes** and the celebration is playing.
  const factory celebrating() = FeedbackSheetCelebrating;

  /// The celebration finished; the sheet asks whether to leave a store review.
  const factory reviewConfirmation() = FeedbackSheetReviewConfirmation;

  /// The user chose **Leave a review**; the sheet is closing.
  const factory reviewAccepted() = FeedbackSheetReviewAccepted;

  /// The user answered **Could be better** and is writing private feedback.
  /// The draft text lives in the composer, which keeps it across failures.
  const factory privateFeedback({
    required Set<FeedbackIssue> issues,
    required FeedbackSubmission submission,
  }) = FeedbackSheetPrivateFeedback;
}

enum FeedbackSubmission() {
  editing,
  submitting,
  failed,
  sent,
}
