import "package:injectable/injectable.dart";

import "../foundation/models/product_analytics/installation_analytics_event.dart";
import "../foundation/models/product_analytics/product_analytics_event.dart";
import "../foundation/platform/analytics_client.dart";

@lazySingleton
class AnalyticsApi {
  final AnalyticsClient _client;

  AnalyticsApi({required AnalyticsClient client}) : _client = client;

  Future<void> logProductEvent({required ProductAnalyticsEnvelope envelope, required String userKey}) {
    return _client.logProductEvent(envelope: envelope, userKey: userKey);
  }

  Future<void> logInstallationEvent({required InstallationAnalyticsEvent event}) {
    return _client.logInstallationEvent(event: event);
  }
}
