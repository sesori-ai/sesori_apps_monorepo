import "package:sesori_dart_core/sesori_dart_core.dart";

/// Every Remote Config flag the app reads, with the value it has until the console
/// sets one. [FirebaseRemoteConfigClient] registers these as Firebase's defaults.
enum BoolRemoteConfig({required final String key, required final bool defaultValue}) {
  voiceLiveEnabled(key: "voice_live_enabled", defaultValue: false),
  voiceOnDeviceEnabled(key: "voice_on_device_enabled", defaultValue: true),
  founderCallEnabled(key: "founder_call_enabled", defaultValue: true),
  founderCallAfterComputer(key: "founder_call_after_computer", defaultValue: true),
}

enum IntRemoteConfig({required final String key, required final int defaultValue}) {
  feedbackPromptInteractionThreshold(
    key: "feedback_prompt_interaction_threshold",
    defaultValue: defaultFeedbackPromptInteractionThreshold,
  ),
  feedbackPromptCooldownDays(key: "feedback_prompt_cooldown_days", defaultValue: defaultFeedbackPromptCooldownDays),
  androidLatestProductionSubmissionBuild(key: "android_latest_production_submission_build", defaultValue: 0),
}

/// A null [defaultValue] means the app has its own built-in text, such as localized
/// wording, which applies until the console sets one.
enum StringRemoteConfig({required final String key, required final String? defaultValue}) {
  founderCallUrl(key: "founder_call_url", defaultValue: defaultFounderCallBookingUrl),
  founderCallTitle(key: "founder_call_title", defaultValue: null),
  founderCallMessage(key: "founder_call_message", defaultValue: null),
  founderCallButton(key: "founder_call_button", defaultValue: null),
}
