import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../di/firebase_register_module.dart";
import "firebase_remote_config_client.dart";

@firebaseEnabledEnvironment
@LazySingleton(as: FeedbackPromptConfigSource)
class FirebaseFeedbackPromptConfigSource({
  required final FirebaseRemoteConfigClient _remoteConfigClient,
}) implements FeedbackPromptConfigSource {
  static const String interactionThresholdKey = "feedback_prompt_interaction_threshold";
  static const String cooldownDaysKey = "feedback_prompt_cooldown_days";

  /// Firebase reports an unset key as zero.
  @override
  Future<FeedbackPromptConfigValues> fetchValues() async {
    final remoteConfig = await _remoteConfigClient.activated();
    return (
      interactionThreshold: remoteConfig.getInt(interactionThresholdKey),
      cooldownDays: remoteConfig.getInt(cooldownDaysKey),
    );
  }
}
