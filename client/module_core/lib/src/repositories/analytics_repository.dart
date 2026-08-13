import "package:injectable/injectable.dart";
import "package:meta/meta.dart";

import "../api/analytics_api.dart";
import "../foundation/models/product_analytics/installation_analytics_event.dart";
import "../foundation/models/product_analytics/product_analytics_event.dart";
import "models/analytics_delivery_result.dart";

const _analyticsDeliveryDeadline = Duration(seconds: 10);

@lazySingleton
class AnalyticsRepository {
  final AnalyticsApi _api;
  final Duration _deliveryDeadline;

  new({required AnalyticsApi api}) : _api = api, _deliveryDeadline = _analyticsDeliveryDeadline;

  @visibleForTesting
  new withDeliveryDeadline({
    required AnalyticsApi api,
    required Duration deliveryDeadline,
  }) : _api = api,
       _deliveryDeadline = deliveryDeadline;

  Future<AnalyticsDeliveryResult> logProductEvent({
    required ProductAnalyticsEnvelope envelope,
    required String userKey,
  }) => _deliver(
    operation: () => _api.logProductEvent(envelope: envelope, userKey: userKey),
  );

  Future<AnalyticsDeliveryResult> logInstallationEvent({required InstallationAnalyticsEvent event}) =>
      _deliver(operation: () => _api.logInstallationEvent(event: event));

  Future<AnalyticsDeliveryResult> _deliver({required Future<void> Function() operation}) async {
    try {
      await operation().timeout(_deliveryDeadline);
      return AnalyticsDeliveryResult.acceptedBySdk;
    } on Object {
      return AnalyticsDeliveryResult.failed;
    }
  }
}
