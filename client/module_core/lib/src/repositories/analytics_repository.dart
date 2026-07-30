import "package:injectable/injectable.dart";

import "../api/analytics_api.dart";
import "../foundation/models/product_analytics/installation_analytics_event.dart";
import "../foundation/models/product_analytics/product_analytics_event.dart";
import "models/analytics_delivery_result.dart";

@lazySingleton
class AnalyticsRepository {
  final AnalyticsApi _api;

  AnalyticsRepository({required AnalyticsApi api}) : _api = api;

  Future<AnalyticsDeliveryResult> logProductEvent({
    required ProductAnalyticsEnvelope envelope,
    required String userKey,
  }) async {
    try {
      await _api.logProductEvent(envelope: envelope, userKey: userKey);
      return AnalyticsDeliveryResult.acceptedBySdk;
    } on Object {
      return AnalyticsDeliveryResult.failed;
    }
  }

  Future<AnalyticsDeliveryResult> logInstallationEvent({required InstallationAnalyticsEvent event}) async {
    try {
      await _api.logInstallationEvent(event: event);
      return AnalyticsDeliveryResult.acceptedBySdk;
    } on Object {
      return AnalyticsDeliveryResult.failed;
    }
  }
}
