import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../foundation/models/product_analytics/analytics_runtime_capability.dart";
import "../foundation/models/product_analytics/attribution_event.dart";
import "../foundation/models/product_analytics/installation_analytics_event.dart";
import "../logging/logging.dart";
import "../repositories/analytics_repository.dart";
import "../repositories/attribution_repository.dart";
import "../repositories/models/analytics_delivery_result.dart";

enum LoginAttemptFailureCause() { authentication, launch, cancelled, timeout, unknown }

@lazySingleton
class InstallationAnalyticsService({
    required final AnalyticsRuntimeCapability _capability,
    required final AnalyticsRepository _repository,
    required final AttributionRepository _attributionRepository,
  }) {

  Future<AnalyticsDeliveryResult> loginAttemptStarted({required AuthProvider provider}) {
    return _log(
      event: InstallationAnalyticsEvent.loginAttemptStarted(
        provider: _analyticsProvider(provider: provider),
      ),
    );
  }

  Future<AnalyticsDeliveryResult> loginAttemptCompleted({
    required AuthProvider provider,
    required AccountStatus accountStatus,
  }) async {
    final results = await Future.wait([
      _log(
        event: InstallationAnalyticsEvent.loginAttemptCompleted(
          provider: _analyticsProvider(provider: provider),
        ),
      ),
      _logAttribution(accountStatus: accountStatus),
    ]);

    return results.every((result) => result == AnalyticsDeliveryResult.acceptedBySdk)
        ? AnalyticsDeliveryResult.acceptedBySdk
        : AnalyticsDeliveryResult.failed;
  }

  Future<AnalyticsDeliveryResult> loginAttemptFailed({
    required AuthProvider provider,
    required LoginAttemptFailureCause cause,
  }) {
    return _log(
      event: InstallationAnalyticsEvent.loginAttemptFailed(
        provider: _analyticsProvider(provider: provider),
        failureKind: _analyticsFailureKind(cause: cause),
      ),
    );
  }

  AnalyticsLoginProvider _analyticsProvider({required AuthProvider provider}) => switch (provider) {
    GitHubAuthProvider() => AnalyticsLoginProvider.github,
    GoogleAuthProvider() => AnalyticsLoginProvider.google,
    AppleAuthProvider() => AnalyticsLoginProvider.apple,
    EmailAuthProvider() => AnalyticsLoginProvider.email,
  };

  AnalyticsLoginFailureKind _analyticsFailureKind({required LoginAttemptFailureCause cause}) => switch (cause) {
    LoginAttemptFailureCause.authentication => AnalyticsLoginFailureKind.authentication,
    LoginAttemptFailureCause.launch => AnalyticsLoginFailureKind.launch,
    LoginAttemptFailureCause.cancelled => AnalyticsLoginFailureKind.cancelled,
    LoginAttemptFailureCause.timeout => AnalyticsLoginFailureKind.timeout,
    LoginAttemptFailureCause.unknown => AnalyticsLoginFailureKind.unknown,
  };

  Future<AnalyticsDeliveryResult> _logAttribution({required AccountStatus accountStatus}) async {
    final results = <AnalyticsDeliveryResult>[];
    if (accountStatus == AccountStatus.created) {
      results.add(await _attributionRepository.logEvent(event: AttributionEvent.accountCreated));
    }
    results.add(await _attributionRepository.logEvent(event: AttributionEvent.accountLogin));

    return results.every((result) => result == AnalyticsDeliveryResult.acceptedBySdk)
        ? AnalyticsDeliveryResult.acceptedBySdk
        : AnalyticsDeliveryResult.failed;
  }

  Future<AnalyticsDeliveryResult> _log({required InstallationAnalyticsEvent event}) async {
    if (!_capability.isEnabled) {
      return AnalyticsDeliveryResult.failed;
    }
    final result = await _repository.logInstallationEvent(event: event);
    if (result == AnalyticsDeliveryResult.failed) {
      logw("Failed to report installation analytics event");
    }
    return result;
  }
}
