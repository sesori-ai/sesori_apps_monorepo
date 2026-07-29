import "package:injectable/injectable.dart";

import "../api/analytics_api.dart";
import "../foundation/models/product_analytics/installation_analytics_event.dart";
import "models/analytics_delivery_result.dart";

@lazySingleton
class InstallationAnalyticsRepository {
  final AnalyticsApi _api;

  InstallationAnalyticsRepository({required AnalyticsApi api}) : _api = api;

  Future<AnalyticsDeliveryResult> logEvent({required InstallationAnalyticsEvent event}) async {
    try {
      await _api.logInstallationEvent(event: event);
      return AnalyticsDeliveryResult.acceptedBySdk;
    } on Object {
      return AnalyticsDeliveryResult.failed;
    }
  }
}
