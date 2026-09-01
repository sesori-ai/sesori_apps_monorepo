import "package:injectable/injectable.dart";
import "package:meta/meta.dart";

import "../api/attribution_api.dart";
import "../foundation/models/product_analytics/attribution_event.dart";
import "../foundation/platform/attribution_claim_storage.dart";
import "../logging/logging.dart";
import "models/analytics_delivery_result.dart";

const _attributionDeliveryDeadline = Duration(seconds: 10);

@lazySingleton
class AttributionRepository._({
  required final AttributionApi _api,
  required final AttributionClaimStorage _claimStorage,
  required final Duration _deliveryDeadline,
}) {
  final Set<String> _claimedKeys = {};

  new({
    required AttributionApi api,
    required AttributionClaimStorage claimStorage,
  }) : this._(
         api: api,
         claimStorage: claimStorage,
         deliveryDeadline: _attributionDeliveryDeadline,
       );

  @visibleForTesting
  new withDeliveryDeadline({
    required AttributionApi api,
    required AttributionClaimStorage claimStorage,
    required Duration deliveryDeadline,
  }) : this._(api: api, claimStorage: claimStorage, deliveryDeadline: deliveryDeadline);

  bool get isReady => _api.isReady;

  Future<AnalyticsDeliveryResult> logEvent({required AttributionEvent event}) async {
    try {
      final claimKey = event.claimKey;
      if (claimKey != null) {
        if (_claimedKeys.contains(claimKey)) return AnalyticsDeliveryResult.acceptedBySdk;
        if (!_api.isReady) return AnalyticsDeliveryResult.failed;
        if (await _claimStorage.isClaimed(claimKey: claimKey)) {
          _claimedKeys.add(claimKey);
          return AnalyticsDeliveryResult.acceptedBySdk;
        }
        // Claim before delivery: a lost event is preferable to a duplicate.
        await _claimStorage.markClaimed(claimKey: claimKey);
        _claimedKeys.add(claimKey);
      }
      await _api.logEvent(event: event).timeout(_deliveryDeadline);
      return AnalyticsDeliveryResult.acceptedBySdk;
    } on Object catch (error, stackTrace) {
      logw("Failed to report attribution event (${event.name})", error, stackTrace);
      return AnalyticsDeliveryResult.failed;
    }
  }
}
