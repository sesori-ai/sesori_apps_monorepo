import "../models/product_analytics/installation_analytics_event.dart";
import "../models/product_analytics/product_analytics_event.dart";

abstract interface class AnalyticsClient() {
  Future<void> logProductEvent({required ProductAnalyticsEnvelope envelope, required String userKey});

  Future<void> logInstallationEvent({required InstallationAnalyticsEvent event});
}
