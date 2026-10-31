import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../di/firebase_register_module.dart";
import "firebase_remote_config_client.dart";
import "remote_config_flags.dart";

@firebaseEnabledEnvironment
@LazySingleton(as: FeedbackPromptConfigSource)
class FirebaseFeedbackPromptConfigSource({
  required final FirebaseRemoteConfigClient _remoteConfigClient,
}) implements FeedbackPromptConfigSource {
  @override
  Future<FeedbackPromptConfigValues> fetchValues() async => (
    interactionThreshold: await _remoteConfigClient.getInt(config: IntRemoteConfig.feedbackPromptInteractionThreshold),
    cooldownDays: await _remoteConfigClient.getInt(config: IntRemoteConfig.feedbackPromptCooldownDays),
  );
}
