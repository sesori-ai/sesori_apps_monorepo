import "package:injectable/injectable.dart";

import "../api/analytics_api.dart";
import "../foundation/models/product_analytics/product_analytics_event.dart";
import "models/analytics_delivery_result.dart";

@lazySingleton
class ProductAnalyticsRepository {
  final AnalyticsApi _api;

  ProductAnalyticsRepository({required AnalyticsApi api}) : _api = api;

  Future<AnalyticsDeliveryResult> logEvent({
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
}
