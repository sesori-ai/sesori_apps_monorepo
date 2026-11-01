import "package:sesori_dart_core/sesori_dart_core.dart" show ProductAnalyticsEnvelope;

/// Layer-0 capability for receiving the product events the shared analytics
/// pipeline has accepted on desktop.
abstract interface class DesktopProductEventSource() {
  /// Single-subscription. Events logged before the one listener arrives wait for
  /// it, and listening a second time throws.
  Stream<ProductAnalyticsEnvelope> get events;
}
