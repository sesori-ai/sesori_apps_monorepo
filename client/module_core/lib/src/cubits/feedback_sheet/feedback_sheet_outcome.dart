/// How the user left one rating sheet.
sealed class const FeedbackSheetOutcome();

/// **Yes, love it!**, then **Leave a review**: a positive answer, and the
/// shell opens the store review page.
final class const FeedbackSheetOutcomeLoveLeaveReview() extends FeedbackSheetOutcome;

/// **Yes, love it!**, then **Not now**, the close button or a swipe down: a
/// positive answer without a review.
final class const FeedbackSheetOutcomeLoveNotNow() extends FeedbackSheetOutcome;

/// The user answered **Could be better**. [sent] is true only when their
/// private feedback reached the server.
final class const FeedbackSheetOutcomeCouldBeBetter({required final bool sent}) extends FeedbackSheetOutcome;

/// The user closed the sheet without answering.
final class const FeedbackSheetOutcomeDismissed() extends FeedbackSheetOutcome;
