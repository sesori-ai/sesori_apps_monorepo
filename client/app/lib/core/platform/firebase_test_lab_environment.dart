import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

enum FirebaseTestLabEnvironmentStatus() { notRunning, running, unknown }

class const FirebaseTestLabEnvironment() {
  static const _channel = MethodChannel("com.sesori.app/firebase-test-lab");

  Future<FirebaseTestLabEnvironmentStatus> detect() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return FirebaseTestLabEnvironmentStatus.notRunning;
    }

    try {
      return switch (await _channel.invokeMethod<bool>("isRunning")) {
        true => FirebaseTestLabEnvironmentStatus.running,
        false => FirebaseTestLabEnvironmentStatus.notRunning,
        null => throw StateError("Firebase Test Lab detection returned no value"),
      };
    } on Object catch (error, stackTrace) {
      logw("Failed to detect the Firebase Test Lab environment", error, stackTrace);
      return FirebaseTestLabEnvironmentStatus.unknown;
    }
  }
}
