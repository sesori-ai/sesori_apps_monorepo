import "package:injectable/injectable.dart";
import "package:meta/meta.dart";

import "../api/attribution_api.dart";
import "../foundation/models/attribution/attribution_event.dart";
import "../logging/logging.dart";
import "models/analytics_delivery_result.dart";

const _attributionDeliveryDeadline = Duration(seconds: 10);

@lazySingleton
class AttributionRepository {
  final AttributionApi _api;
  final Duration _deliveryDeadline;

  new({required AttributionApi api}) : _api = api, _deliveryDeadline = _attributionDeliveryDeadline;

  @visibleForTesting
  new withDeliveryDeadline({
    required AttributionApi api,
    required Duration deliveryDeadline,
  }) : _api = api,
       _deliveryDeadline = deliveryDeadline;

  Future<AnalyticsDeliveryResult> logEvent({required AttributionEvent event}) async {
    try {
      await _api.logEvent(event: event).timeout(_deliveryDeadline);
      return AnalyticsDeliveryResult.acceptedBySdk;
    } on Object catch (error, stackTrace) {
      logw("Failed to report attribution event (${event.name})", error, stackTrace);
      return AnalyticsDeliveryResult.failed;
    }
  }
}
