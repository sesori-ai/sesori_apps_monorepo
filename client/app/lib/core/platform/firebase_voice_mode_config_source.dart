import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../di/firebase_register_module.dart";
import "firebase_remote_config_client.dart";
import "remote_config_flags.dart";

@firebaseEnabledEnvironment
@LazySingleton(as: VoiceModeConfigSource)
class FirebaseVoiceModeConfigSource({
  required final FirebaseRemoteConfigClient _remoteConfigClient,
}) implements VoiceModeConfigSource {
  @override
  Future<bool> fetchLiveEnabled() => _remoteConfigClient.getBool(config: BoolRemoteConfig.voiceLiveEnabled);
}
