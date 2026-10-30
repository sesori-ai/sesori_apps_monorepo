import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../di/firebase_register_module.dart";
import "firebase_remote_config_client.dart";

@firebaseEnabledEnvironment
@LazySingleton(as: VoiceModeConfigSource)
class FirebaseVoiceModeConfigSource({
  required final FirebaseRemoteConfigClient _remoteConfigClient,
}) implements VoiceModeConfigSource {
  static const String liveEnabledKey = "voice_live_enabled";
  static const String presentationKey = "voice_live_presentation";

  /// Firebase reports an unset key as false or as an empty string.
  @override
  Future<VoiceModeConfigValues> fetchValues() async {
    final remoteConfig = await _remoteConfigClient.activated();
    final presentation = remoteConfig.getString(presentationKey);
    return (
      liveEnabled: remoteConfig.getBool(liveEnabledKey),
      presentation: presentation.isEmpty ? null : presentation,
    );
  }
}
