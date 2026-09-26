/// How the user left one rating sheet.
sealed class const FeedbackSheetOutcome();

/// **Yes, love it!**, then **Leave a review**: a positive answer, and the
/// shell opens the store review page.
final class const FeedbackSheetOutcomeLoveLeaveReview() extends FeedbackSheetOutcome;

/// **Yes, love it!**, then **Not now**, the close button or a swipe down: a
/// positive answer without a review.
final class const FeedbackSheetOutcomeLoveNotNow() extends FeedbackSheetOutcome;

/// The user answered **Could be better**.
final class const FeedbackSheetOutcomeCouldBeBetter() extends FeedbackSheetOutcome;

/// The user closed the sheet without answering.
final class const FeedbackSheetOutcomeDismissed() extends FeedbackSheetOutcome;
