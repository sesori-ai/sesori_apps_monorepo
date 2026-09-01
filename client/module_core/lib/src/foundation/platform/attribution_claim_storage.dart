import "../models/product_analytics/attribution_event.dart";

/// App-container persistence for the attribution events claimed once per install.
abstract interface class AttributionClaimStorage() {
  Future<bool> isClaimed({required AttributionEvent event});

  Future<void> markClaimed({required AttributionEvent event});
}
