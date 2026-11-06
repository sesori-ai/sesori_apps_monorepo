/// When the rating prompt opens by itself: right after the finished agent turn
/// that brings the points across sessions to [interactionThreshold], and no
/// sooner than [cooldown] after it last did.
final class const FeedbackPromptConfig({
  required final int interactionThreshold,
  required final Duration cooldown,
});
