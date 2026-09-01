import "../models/product_analytics/attribution_event.dart";

/// Platform attribution sink. Unsupported products provide a no-op adapter.
abstract interface class AttributionClient() {
  /// Whether the platform sink has completed its startup gate.
  bool get isReady;

  Future<void> logEvent({required AttributionEvent event});
}
