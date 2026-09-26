/// This device's progress toward the automatic rating sheet.
sealed class const FeedbackPromptState();

/// Counting good interactions toward the next automatic showing.
///
/// [positiveCount] is the number of big successful interactions since the last
/// meaningful error or showing. [lastShownAt] is when the sheet last opened by
/// itself, or null when it never has; the cooldown runs from it.
final class const FeedbackPromptCounting({
  required final int positiveCount,
  required final DateTime? lastShownAt,
}) extends FeedbackPromptState;

/// The user answered **Yes**, so the sheet never opens by itself again.
final class const FeedbackPromptRetired() extends FeedbackPromptState;
