import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../di/firebase_register_module.dart";

@firebaseDisabledEnvironment
@LazySingleton(as: VoiceModeConfigSource)
class NoOpVoiceModeConfigSource() implements VoiceModeConfigSource {
  @override
  Future<bool> fetchLiveEnabled() async => false;

  @override
  Future<bool> fetchOnDeviceEnabled() async => true;
}
