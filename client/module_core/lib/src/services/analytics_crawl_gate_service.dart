import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../logging/logging.dart";
import "../repositories/analytics_release_cutoff_repository.dart";
import "../repositories/installed_app_build_repository.dart";

enum AnalyticsCrawlGateEligibility() {
  eligibleRelease,
  ineligible
}

enum AnalyticsStoreCrawlGate() {
  allow,
  suspend
}

@lazySingleton
class AnalyticsCrawlGateService({
  required final AuthSession _authSession,
  required final AnalyticsReleaseCutoffRepository _releaseCutoffRepository,
  required final InstalledAppBuildRepository _installedAppBuildRepository,
}) {
  Future<AnalyticsStoreCrawlGate> resolve({required AnalyticsCrawlGateEligibility eligibility}) async {
    if (eligibility != AnalyticsCrawlGateEligibility.eligibleRelease) {
      return AnalyticsStoreCrawlGate.allow;
    }
    if (await _authSession.hasLocallyValidSession()) {
      return AnalyticsStoreCrawlGate.allow;
    }

    final releaseCutoff = await _releaseCutoffRepository.fetchLatestSubmittedProductionBuild();
    if (releaseCutoff == null) return AnalyticsStoreCrawlGate.allow;
    final installedBuild = await _installedAppBuildRepository.read();
    if (installedBuild == null || installedBuild.buildNumber <= releaseCutoff.buildNumber) {
      return AnalyticsStoreCrawlGate.allow;
    }

    logi(
      "Suspending analytics for unauthenticated build ${installedBuild.buildNumber}; "
      "latest production submission is ${releaseCutoff.buildNumber}",
    );
    return AnalyticsStoreCrawlGate.suspend;
  }
}
