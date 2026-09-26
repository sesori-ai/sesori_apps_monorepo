/// When the rating sheet opens by itself: after [interactionThreshold] good
/// interactions in a row, and no sooner than [cooldown] after it last did.
final class const FeedbackPromptConfig({
  required final int interactionThreshold,
  required final Duration cooldown,
});
