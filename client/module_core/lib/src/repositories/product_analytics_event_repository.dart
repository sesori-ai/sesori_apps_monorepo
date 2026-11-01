import "package:injectable/injectable.dart";

import "../api/product_analytics_event_api.dart";
import "../foundation/models/product_analytics/product_analytics_event.dart";
import "../foundation/models/product_analytics/product_analytics_event_delivery.dart";

@lazySingleton
class ProductAnalyticsEventRepository({required final ProductAnalyticsEventApi _api}) {
  /// Makes one attempt. The caller decides which [params] an event carries.
  Future<ProductAnalyticsEventDeliveryResult> send({
    required String userId,
    required ProductAnalyticsEventPlatform platform,
    required String appVersion,
    required ProductAnalyticsEnvelope envelope,
    required Map<String, String> params,
  }) => _api.send(
    userId: userId,
    request: ProductAnalyticsEventRequest(
      schemaVersion: ProductAnalyticsEventSchemaVersion.v1,
      platform: platform,
      appVersion: appVersion,
      name: envelope.event.wireName,
      occurredAtMicros: envelope.occurredAtUtc.microsecondsSinceEpoch,
      params: params,
    ),
  );
}
