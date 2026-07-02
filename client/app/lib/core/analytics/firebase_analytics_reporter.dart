import "package:firebase_analytics/firebase_analytics.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "analytics_event.dart";
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
  Future<void> logEvent({required AnalyticsEvent event}) async {
    try {
      // The union discriminator is the GA4 event name; the case's remaining
      // fields are the event's parameters.
      final json = event.toJson();
      final name = json.remove(analyticsEventNameKey) as String;
      await _analytics.logEvent(
        name: name,
        parameters: json.isEmpty ? null : json.map((key, value) => MapEntry(key, value as Object)),
      );
    } on Object catch (error, stackTrace) {
      // Best-effort: a failed analytics write must never reach the user.
      logw("Failed to log analytics event: ${event.toString()}", error, stackTrace);
    }
  }
}
