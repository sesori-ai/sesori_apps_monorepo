import "package:firebase_remote_config/firebase_remote_config.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../di/firebase_register_module.dart";

@firebaseEnabledEnvironment
@LazySingleton(as: AndroidAnalyticsReleaseCutoffSource)
class FirebaseAndroidAnalyticsReleaseCutoffSource({
  required final FirebaseRemoteConfig _remoteConfig,
}) implements AndroidAnalyticsReleaseCutoffSource {
  static const String parameterKey = "android_latest_production_submission_build";
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
        logw("Firebase Remote Config did not return a fresh Android analytics release cutoff");
        return null;
      }
      await _remoteConfig.activate();
      return _remoteConfig.getInt(parameterKey);
    } on Object catch (error, stackTrace) {
      logw("Failed to fetch the Android analytics release cutoff", error, stackTrace);
      return null;
    }
  }
}
