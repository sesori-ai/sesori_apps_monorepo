import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../di/firebase_register_module.dart";
import "firebase_remote_config_client.dart";
import "remote_config_flags.dart";

@firebaseEnabledEnvironment
@LazySingleton(as: FounderCallConfigSource)
class FirebaseFounderCallConfigSource({
  required final FirebaseRemoteConfigClient _remoteConfigClient,
}) implements FounderCallConfigSource {
  @override
  Future<FounderCallConfigValues> fetchValues() async => (
    enabled: await _remoteConfigClient.getBool(config: BoolRemoteConfig.founderCallEnabled),
    afterComputer: await _remoteConfigClient.getBool(config: BoolRemoteConfig.founderCallAfterComputer),
    bookingUrl: await _remoteConfigClient.getString(config: StringRemoteConfig.founderCallUrl),
    title: await _remoteConfigClient.getString(config: StringRemoteConfig.founderCallTitle),
    message: await _remoteConfigClient.getString(config: StringRemoteConfig.founderCallMessage),
    buttonLabel: await _remoteConfigClient.getString(config: StringRemoteConfig.founderCallButton),
  );
}
