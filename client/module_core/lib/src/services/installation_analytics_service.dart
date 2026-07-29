import "package:injectable/injectable.dart";

import "../foundation/models/product_analytics/analytics_runtime_capability.dart";
import "../foundation/models/product_analytics/installation_analytics_event.dart";
import "../repositories/installation_analytics_repository.dart";
import "../repositories/models/analytics_delivery_result.dart";

@lazySingleton
class InstallationAnalyticsService {
  final AnalyticsRuntimeCapability _capability;
  final InstallationAnalyticsRepository _repository;

  InstallationAnalyticsService({
    required AnalyticsRuntimeCapability capability,
    required InstallationAnalyticsRepository repository,
  }) : _capability = capability,
       _repository = repository;

  Future<AnalyticsDeliveryResult> loginAttemptStarted({required AnalyticsLoginProvider provider}) {
    return _log(event: InstallationAnalyticsEvent.loginAttemptStarted(provider: provider));
  }

  Future<AnalyticsDeliveryResult> loginAttemptCompleted({required AnalyticsLoginProvider provider}) {
    return _log(event: InstallationAnalyticsEvent.loginAttemptCompleted(provider: provider));
  }

  Future<AnalyticsDeliveryResult> loginAttemptFailed({
    required AnalyticsLoginProvider provider,
    required AnalyticsLoginFailureKind failureKind,
  }) {
    return _log(
      event: InstallationAnalyticsEvent.loginAttemptFailed(provider: provider, failureKind: failureKind),
    );
  }

  Future<AnalyticsDeliveryResult> _log({required InstallationAnalyticsEvent event}) {
    if (!_capability.isEnabled) {
      return Future.value(AnalyticsDeliveryResult.failed);
    }
    return _repository.logEvent(event: event);
  }
}
