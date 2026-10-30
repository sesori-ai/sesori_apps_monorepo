import "package:firebase_remote_config/firebase_remote_config.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../di/firebase_register_module.dart";
import "firebase_remote_config_client.dart";

@firebaseEnabledEnvironment
@LazySingleton(as: FounderCallConfigSource)
class FirebaseFounderCallConfigSource({
  required final FirebaseRemoteConfigClient _remoteConfigClient,
}) implements FounderCallConfigSource {
  static const String enabledKey = "founder_call_enabled";
  static const String afterComputerKey = "founder_call_after_computer";
  static const String bookingUrlKey = "founder_call_url";
  static const String titleKey = "founder_call_title";
  static const String messageKey = "founder_call_message";
  static const String buttonLabelKey = "founder_call_button";

  /// A key the console never set, or set to an empty string, reads as null so
  /// the app's built-in default applies.
  @override
  Future<FounderCallConfigValues> fetchValues() async {
    final remoteConfig = await _remoteConfigClient.activated();
    RemoteConfigValue? read(String key) {
      final value = remoteConfig.getValue(key);
      return value.source == ValueSource.valueStatic || value.asString().isEmpty ? null : value;
    }

    return (
      enabled: read(enabledKey)?.asBool(),
      afterComputer: read(afterComputerKey)?.asBool(),
      bookingUrl: read(bookingUrlKey)?.asString(),
      title: read(titleKey)?.asString(),
      message: read(messageKey)?.asString(),
      buttonLabel: read(buttonLabelKey)?.asString(),
    );
  }
}
