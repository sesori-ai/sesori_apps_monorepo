import "../models/product_analytics/installation_analytics_event.dart";
import "../models/product_analytics/product_analytics_event.dart";

abstract interface class AnalyticsClient() {
  Future<void> logProductEvent({required ProductAnalyticsEnvelope envelope, required String userKey});

  Future<void> logInstallationEvent({required InstallationAnalyticsEvent event});

  /// Lifts any store-crawl suspension of the underlying SDK. Called when a
  /// server-confirmed interactive authentication proves this process is a
  /// person rather than a crawler; a no-op when nothing is suspended.
  Future<void> activateAfterInteractiveAuthentication();
}
