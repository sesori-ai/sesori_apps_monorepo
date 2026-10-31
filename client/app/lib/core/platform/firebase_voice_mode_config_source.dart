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
  static const String onDeviceDisabledKey = "voice_on_device_disabled";

  /// Firebase reports an unset key as false.
  @override
  Future<bool> fetchLiveEnabled() async {
    final remoteConfig = await _remoteConfigClient.activated();
    return remoteConfig.getBool(liveEnabledKey);
  }

  /// A kill switch, so an unset key, which Firebase reports as false, leaves
  /// on-device transcription on.
  @override
  Future<bool> fetchOnDeviceEnabled() async {
    final remoteConfig = await _remoteConfigClient.activated();
    return !remoteConfig.getBool(onDeviceDisabledKey);
  }
}
