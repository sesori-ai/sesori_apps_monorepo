import "package:firebase_remote_config/firebase_remote_config.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../di/firebase_register_module.dart";
import "remote_config_flags.dart";

/// Fetches Remote Config once per launch for the sources that read plain
/// values. The analytics release cutoff keeps its own fetch because it must
/// tell a fresh fetch from stale values.
@firebaseEnabledEnvironment
@lazySingleton
class FirebaseRemoteConfigClient({
  required final FirebaseRemoteConfig _remoteConfig,
}) {
  static const Duration _fetchTimeout = Duration(seconds: 3);

  late final Future<void> _activated = _fetchAndActivate();

  /// The flag's fresh value, the one activated on an earlier launch when the fetch
  /// fails, or else its default.
  Future<bool> getBool({required BoolRemoteConfig config}) async {
    await _activated;
    return _remoteConfig.getBool(config.key);
  }

  Future<int> getInt({required IntRemoteConfig config}) async {
    await _activated;
    return _remoteConfig.getInt(config.key);
  }

  /// Null when the flag has no text, since the console can also set an empty one.
  Future<String?> getString({required StringRemoteConfig config}) async {
    await _activated;
    final value = _remoteConfig.getString(config.key);
    return value.isEmpty ? null : value;
  }

  Future<void> _fetchAndActivate() async {
    try {
      await _remoteConfig.setDefaults({
        for (final config in BoolRemoteConfig.values) config.key: config.defaultValue,
        for (final config in IntRemoteConfig.values) config.key: config.defaultValue,
        for (final config in StringRemoteConfig.values) config.key: ?config.defaultValue,
      });
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: _fetchTimeout,
          minimumFetchInterval: Duration.zero,
        ),
      );
      await _remoteConfig.fetchAndActivate();
    } on Object catch (error, stackTrace) {
      logw("Failed to fetch Remote Config; using the last activated values", error, stackTrace);
    }
  }
}
