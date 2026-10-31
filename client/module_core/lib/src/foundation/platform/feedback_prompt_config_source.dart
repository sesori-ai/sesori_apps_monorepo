const int defaultFeedbackPromptInteractionThreshold = 5;
const int defaultFeedbackPromptCooldownDays = 14;

/// Raw remote values for the automatic rating sheet. Either is null when the
/// source has none; the repository validates them and applies the defaults.
typedef FeedbackPromptConfigValues = ({int? interactionThreshold, int? cooldownDays});

abstract interface class FeedbackPromptConfigSource() {
  Future<FeedbackPromptConfigValues> fetchValues();
}
