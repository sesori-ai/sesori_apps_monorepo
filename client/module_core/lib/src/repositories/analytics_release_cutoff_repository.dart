import "package:injectable/injectable.dart";

import "../api/analytics_release_cutoff_api.dart";
import "../logging/logging.dart";
import "models/analytics_release_cutoff.dart";

@lazySingleton
class AnalyticsReleaseCutoffRepository({required final AnalyticsReleaseCutoffApi _api}) {
  Future<AnalyticsReleaseCutoff?> fetchLatestSubmittedProductionBuild() async {
    final buildNumber = await _api.fetchLatestSubmittedProductionBuild();
    if (buildNumber == null) return null;
    if (buildNumber <= 0) {
      logw("Analytics release cutoff source returned an invalid build number: $buildNumber");
      return null;
    }
    return AnalyticsReleaseCutoff(buildNumber: buildNumber);
  }
}
