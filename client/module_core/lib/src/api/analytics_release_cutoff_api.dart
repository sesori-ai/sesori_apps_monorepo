import "package:injectable/injectable.dart";

import "../foundation/platform/analytics_release_cutoff_source.dart";

@lazySingleton
class AnalyticsReleaseCutoffApi({required final AnalyticsReleaseCutoffSource _source}) {
  Future<int?> fetchLatestSubmittedProductionBuild() => _source.fetchLatestSubmittedProductionBuild();
}
