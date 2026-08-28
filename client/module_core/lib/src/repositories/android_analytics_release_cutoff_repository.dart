import "package:injectable/injectable.dart";

import "../api/android_analytics_release_cutoff_api.dart";
import "../logging/logging.dart";
import "models/android_analytics_release_cutoff.dart";

@lazySingleton
class AndroidAnalyticsReleaseCutoffRepository({
  required final AndroidAnalyticsReleaseCutoffApi _api,
}) {
  Future<AndroidAnalyticsReleaseCutoff?> fetchLatestSubmittedProductionBuild() async {
    final buildNumber = await _api.fetchLatestSubmittedProductionBuild();
    if (buildNumber == null) return null;
    if (buildNumber <= 0) {
      logw("Android analytics release cutoff source returned an invalid build number: $buildNumber");
      return null;
    }
    return AndroidAnalyticsReleaseCutoff(buildNumber: buildNumber);
  }
}
