import "package:firebase_analytics/firebase_analytics.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../di/firebase_register_module.dart";

@firebaseEnabledEnvironment
@LazySingleton(as: AnalyticsClient)
class FirebaseAnalyticsClient({
  required final FirebaseAnalytics _analytics,
  required final AnalyticsRuntimeCapability _capability,
}) implements AnalyticsClient {
  @override
  Future<void> logProductEvent({required ProductAnalyticsEnvelope envelope, required String userKey}) async {
    if (!_capability.isEnabled) throw StateError("Product analytics runtime is disabled");
    if (!isValidProductAnalyticsUserKey(value: userKey)) throw ArgumentError.value(userKey, "userKey");
    final event = envelope.event;
    await _analytics.logEvent(
      name: event.wireName,
      parameters: {
        ...event.parameters,
        "schema_version": 1,
        "user_key": userKey,
        "occurred_at_micros": envelope.occurredAtUtc.microsecondsSinceEpoch,
      },
    );
    if (event case ProductScreenViewedEvent(:final screen)) {
      try {
        // Vendor reports key screens by class by default, and a Flutter app
        // has no native screen class to report — carry the pinned screen
        // identity in both dimensions so neither reads as a constant.
        await _analytics.logScreenView(screenName: screen.wireValue, screenClass: screen.wireValue);
      } on Object catch (error, stackTrace) {
        logw("Failed to mirror product analytics screen view", error, stackTrace);
      }
    }
  }

  @override
  Future<void> logInstallationEvent({required InstallationAnalyticsEvent event}) {
    if (!_capability.isEnabled) throw StateError("Installation analytics runtime is disabled");
    return _analytics.logEvent(
      name: event.wireName,
      parameters: {...event.parameters, "schema_version": 1},
    );
  }
}
