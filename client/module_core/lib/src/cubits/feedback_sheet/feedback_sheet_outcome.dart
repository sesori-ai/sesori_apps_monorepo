/// How the user left one rating sheet.
sealed class const FeedbackSheetOutcome();

/// The user answered **Yes, love it!**. [leaveReview] is true only when they
/// then chose **Leave a review**; **Not now** or closing the confirmation step
/// still counts as a positive answer.
final class const FeedbackSheetOutcomeLove({required final bool leaveReview}) extends FeedbackSheetOutcome;

/// The user answered **Could be better**.
final class const FeedbackSheetOutcomeCouldBeBetter() extends FeedbackSheetOutcome;

/// The user closed the sheet without answering.
final class const FeedbackSheetOutcomeDismissed() extends FeedbackSheetOutcome;
