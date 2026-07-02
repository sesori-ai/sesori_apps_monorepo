import "package:firebase_analytics/firebase_analytics.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "analytics_reporter.dart";

/// Forwards user-action events to Firebase Analytics.
///
/// Registered as the [AnalyticsReporter] binding; on builds where Firebase is
/// not initialized the DI setup swaps in `NoOpAnalyticsReporter` instead, so
/// this class can assume a live Firebase app.
@LazySingleton(as: AnalyticsReporter)
class FirebaseAnalyticsReporter implements AnalyticsReporter {
  final FirebaseAnalytics _analytics;

  FirebaseAnalyticsReporter({required FirebaseAnalytics analytics}) : _analytics = analytics;

  @override
  Future<void> logEvent({required String name, required Map<String, Object>? parameters}) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } on Object catch (error, stackTrace) {
      // Best-effort: a failed analytics write must never reach the user.
      logw("Failed to log analytics event: $name", error, stackTrace);
    }
  }
}
