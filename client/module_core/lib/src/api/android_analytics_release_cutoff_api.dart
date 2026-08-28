import "package:injectable/injectable.dart";

import "../foundation/platform/android_analytics_release_cutoff_source.dart";

@lazySingleton
class AndroidAnalyticsReleaseCutoffApi({
  required final AndroidAnalyticsReleaseCutoffSource _source,
}) {
  Future<int?> fetchLatestSubmittedProductionBuild() => _source.fetchLatestSubmittedProductionBuild();
}
