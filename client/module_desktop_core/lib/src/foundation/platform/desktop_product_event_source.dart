import "package:sesori_dart_core/sesori_dart_core.dart" show ProductAnalyticsEnvelope;

/// Layer-0 capability for receiving the product events the shared analytics
/// pipeline has accepted on desktop.
abstract interface class DesktopProductEventSource() {
  /// Single-subscription. Events logged before the one listener arrives wait for
  /// it, and listening a second time throws. Once listening, delivery is
  /// synchronous, so the listener runs in the stack of whoever logged the event.
  Stream<ProductAnalyticsEnvelope> get events;
}
