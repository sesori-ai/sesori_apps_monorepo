import "package:firebase_analytics/firebase_analytics.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

@LazySingleton(as: AnalyticsClient)
class FirebaseAnalyticsClient implements AnalyticsClient {
  static final _userKeyPattern = RegExp(r"^[a-f0-9]{64}$");

  final FirebaseAnalytics _analytics;
  final AnalyticsRuntimeCapability _capability;

  FirebaseAnalyticsClient({
    required FirebaseAnalytics analytics,
    required AnalyticsRuntimeCapability capability,
  }) : _analytics = analytics,
       _capability = capability;

  @override
  Future<void> logProductEvent({required ProductAnalyticsEnvelope envelope, required String userKey}) async {
    if (!_capability.isEnabled) throw StateError("Product analytics runtime is disabled");
    if (!_userKeyPattern.hasMatch(userKey)) throw ArgumentError.value(userKey, "userKey");
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
        await _analytics.logScreenView(screenName: screen.wireValue, screenClass: "GoRouter");
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
