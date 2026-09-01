import "package:injectable/injectable.dart";
import "package:meta/meta.dart";

import "../api/attribution_api.dart";
import "../foundation/models/product_analytics/attribution_event.dart";
import "../foundation/platform/attribution_claim_storage.dart";
import "../logging/logging.dart";
import "models/analytics_delivery_result.dart";

const _attributionDeliveryDeadline = Duration(seconds: 10);

enum _AttributionClaimResult() {
  claimed,
  alreadyClaimed,
}

@lazySingleton
class AttributionRepository._({
  required final AttributionApi _api,
  required final AttributionClaimStorage _claimStorage,
  required final Duration _deliveryDeadline,
}) {
  final Set<AttributionEvent> _claimedEvents = {};
  final Map<AttributionEvent, Future<_AttributionClaimResult>> _activeClaims = {};

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

  Future<AnalyticsDeliveryResult> logEvent({required AttributionEvent event}) async {
    try {
      if (_isOneShot(event: event)) {
        if (!_api.isReady) return AnalyticsDeliveryResult.failed;
        final claimResult = await _claimOnce(event: event);
        if (claimResult == _AttributionClaimResult.alreadyClaimed) {
          return AnalyticsDeliveryResult.acceptedBySdk;
        }
      }
      await _api.logEvent(event: event).timeout(_deliveryDeadline);
      return AnalyticsDeliveryResult.acceptedBySdk;
    } on Object catch (error, stackTrace) {
      logw("Failed to report attribution event (${event.name})", error, stackTrace);
      return AnalyticsDeliveryResult.failed;
    }
  }

  bool _isOneShot({required AttributionEvent event}) => switch (event) {
    AttributionEvent.bridgePaired || AttributionEvent.firstSessionRun => true,
    AttributionEvent.accountCreated || AttributionEvent.accountLogin => false,
  };

  Future<_AttributionClaimResult> _claimOnce({required AttributionEvent event}) async {
    final activeClaim = _activeClaims[event];
    if (activeClaim != null) {
      await activeClaim;
      return _AttributionClaimResult.alreadyClaimed;
    }
    if (_claimedEvents.contains(event)) return _AttributionClaimResult.alreadyClaimed;

    late final Future<_AttributionClaimResult> claim;
    claim = _persistClaim(event: event).whenComplete(() {
      if (identical(_activeClaims[event], claim)) _activeClaims.remove(event);
    });
    _activeClaims[event] = claim;
    return await claim;
  }

  Future<_AttributionClaimResult> _persistClaim({required AttributionEvent event}) async {
    if (await _claimStorage.isClaimed(event: event)) {
      _claimedEvents.add(event);
      return _AttributionClaimResult.alreadyClaimed;
    }
    await _claimStorage.markClaimed(event: event);
    _claimedEvents.add(event);
    return _AttributionClaimResult.claimed;
  }
}
