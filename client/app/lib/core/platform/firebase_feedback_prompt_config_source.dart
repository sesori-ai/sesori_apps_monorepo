import "package:firebase_remote_config/firebase_remote_config.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../di/firebase_register_module.dart";

@firebaseEnabledEnvironment
@LazySingleton(as: FeedbackPromptConfigSource)
class FirebaseFeedbackPromptConfigSource({
  required final FirebaseRemoteConfig _remoteConfig,
}) implements FeedbackPromptConfigSource {
  static const String interactionThresholdKey = "feedback_prompt_interaction_threshold";
  static const String cooldownDaysKey = "feedback_prompt_cooldown_days";
  static const Duration _fetchTimeout = Duration(seconds: 3);

  /// Fetches fresh values, falling back to the values activated on an earlier
  /// launch when the fetch fails. Firebase reports an unset key as zero.
  @override
  Future<FeedbackPromptConfigValues> fetchValues() async {
    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: _fetchTimeout,
          minimumFetchInterval: Duration.zero,
        ),
      );
      await _remoteConfig.fetchAndActivate();
    } on Object catch (error, stackTrace) {
      logw("Failed to fetch the feedback prompt config; using the last activated values", error, stackTrace);
    }
    return (
      interactionThreshold: _remoteConfig.getInt(interactionThresholdKey),
      cooldownDays: _remoteConfig.getInt(cooldownDaysKey),
    );
  }
}
