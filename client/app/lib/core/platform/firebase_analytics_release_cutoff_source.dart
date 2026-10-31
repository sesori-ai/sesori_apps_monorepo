import "package:firebase_remote_config/firebase_remote_config.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../di/firebase_register_module.dart";
import "remote_config_flags.dart";

@firebaseEnabledEnvironment
@LazySingleton(as: AnalyticsReleaseCutoffSource)
class FirebaseAnalyticsReleaseCutoffSource({
  required final FirebaseRemoteConfig _remoteConfig,
}) implements AnalyticsReleaseCutoffSource {
  static const Duration _fetchTimeout = Duration(seconds: 3);

  @override
  Future<int?> fetchLatestSubmittedProductionBuild() async {
    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: _fetchTimeout,
          minimumFetchInterval: Duration.zero,
        ),
      );
      await _remoteConfig.fetch();
      if (_remoteConfig.lastFetchStatus != RemoteConfigFetchStatus.success) {
        logw("Firebase Remote Config did not return a fresh analytics release cutoff");
        return null;
      }
      await _remoteConfig.activate();
      return _remoteConfig.getInt(IntRemoteConfig.androidLatestProductionSubmissionBuild.key);
    } on Object catch (error, stackTrace) {
      logw("Failed to fetch the analytics release cutoff", error, stackTrace);
      return null;
    }
  }
}
