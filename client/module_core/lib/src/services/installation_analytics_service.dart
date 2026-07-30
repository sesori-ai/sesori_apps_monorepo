import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../foundation/models/product_analytics/analytics_runtime_capability.dart";
import "../foundation/models/product_analytics/installation_analytics_event.dart";
import "../repositories/analytics_repository.dart";
import "../repositories/models/analytics_delivery_result.dart";

enum LoginAttemptFailureCause { authentication, launch, cancelled, timeout, unknown }

@lazySingleton
class InstallationAnalyticsService {
  final AnalyticsRuntimeCapability _capability;
  final AnalyticsRepository _repository;

  InstallationAnalyticsService({
    required AnalyticsRuntimeCapability capability,
    required AnalyticsRepository repository,
  }) : _capability = capability,
       _repository = repository;

  Future<AnalyticsDeliveryResult> loginAttemptStarted({required AuthProvider provider}) {
    return _log(event: InstallationAnalyticsEvent.loginAttemptStarted(provider: _analyticsProvider(provider)));
  }

  Future<AnalyticsDeliveryResult> loginAttemptCompleted({required AuthProvider provider}) {
    return _log(event: InstallationAnalyticsEvent.loginAttemptCompleted(provider: _analyticsProvider(provider)));
  }

  Future<AnalyticsDeliveryResult> loginAttemptFailed({
    required AuthProvider provider,
    required LoginAttemptFailureCause cause,
  }) {
    return _log(
      event: InstallationAnalyticsEvent.loginAttemptFailed(
        provider: _analyticsProvider(provider),
        failureKind: _analyticsFailureKind(cause),
      ),
    );
  }

  AnalyticsLoginProvider _analyticsProvider(AuthProvider provider) => switch (provider) {
    GitHubAuthProvider() => AnalyticsLoginProvider.github,
    GoogleAuthProvider() => AnalyticsLoginProvider.google,
    AppleAuthProvider() => AnalyticsLoginProvider.apple,
    EmailAuthProvider() => AnalyticsLoginProvider.email,
  };

  AnalyticsLoginFailureKind _analyticsFailureKind(LoginAttemptFailureCause cause) => switch (cause) {
    LoginAttemptFailureCause.authentication => AnalyticsLoginFailureKind.authentication,
    LoginAttemptFailureCause.launch => AnalyticsLoginFailureKind.launch,
    LoginAttemptFailureCause.cancelled => AnalyticsLoginFailureKind.cancelled,
    LoginAttemptFailureCause.timeout => AnalyticsLoginFailureKind.timeout,
    LoginAttemptFailureCause.unknown => AnalyticsLoginFailureKind.unknown,
  };

  Future<AnalyticsDeliveryResult> _log({required InstallationAnalyticsEvent event}) {
    if (!_capability.isEnabled) {
      return Future.value(AnalyticsDeliveryResult.failed);
    }
    return _repository.logInstallationEvent(event: event);
  }
}
