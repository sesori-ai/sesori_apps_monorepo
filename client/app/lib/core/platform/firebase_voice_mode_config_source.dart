import "package:firebase_remote_config/firebase_remote_config.dart";
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
  static const String onDeviceEnabledKey = "voice_on_device_enabled";

  /// Firebase reports an unset key as false.
  @override
  Future<bool> fetchLiveEnabled() async {
    final remoteConfig = await _remoteConfigClient.activated();
    return remoteConfig.getBool(liveEnabledKey);
  }

  /// True unless the console sets it to false. `getBool` can't tell, since it
  /// reports an unset key as false.
  @override
  Future<bool> fetchOnDeviceEnabled() async {
    final remoteConfig = await _remoteConfigClient.activated();
    final value = remoteConfig.getValue(onDeviceEnabledKey);
    return value.source == ValueSource.valueStatic || value.asBool();
  }
}
