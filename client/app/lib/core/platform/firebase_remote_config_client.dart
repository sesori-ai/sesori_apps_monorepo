import "package:firebase_remote_config/firebase_remote_config.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../di/firebase_register_module.dart";

/// Fetches Remote Config once per launch for the sources that read plain
/// values. The analytics release cutoff keeps its own fetch because it must
/// tell a fresh fetch from stale values.
@firebaseEnabledEnvironment
@lazySingleton
class FirebaseRemoteConfigClient({
  required final FirebaseRemoteConfig _remoteConfig,
}) {
  static const Duration _fetchTimeout = Duration(seconds: 3);

  late final Future<FirebaseRemoteConfig> _activated = _fetchAndActivate();

  /// The config with fresh values, or with the values activated on an earlier
  /// launch when the fetch fails.
  Future<FirebaseRemoteConfig> activated() => _activated;

  Future<FirebaseRemoteConfig> _fetchAndActivate() async {
    try {
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
    return _remoteConfig;
  }
}
