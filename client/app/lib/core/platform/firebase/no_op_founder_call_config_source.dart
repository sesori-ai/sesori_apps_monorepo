import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../di/firebase_register_module.dart";

/// Without Firebase every value takes the app's built-in default.
@firebaseDisabledEnvironment
@LazySingleton(as: FounderCallConfigSource)
class NoOpFounderCallConfigSource() implements FounderCallConfigSource {
  @override
  Future<FounderCallConfigValues> fetchValues() async => (
    enabled: null,
    afterComputer: null,
    bookingUrl: null,
    title: null,
    message: null,
    buttonLabel: null,
  );
}
