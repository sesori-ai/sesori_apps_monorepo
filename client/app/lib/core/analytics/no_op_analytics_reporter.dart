import "analytics_event.dart";
import "analytics_reporter.dart";

/// Discards analytics events on builds where Firebase is not initialized
/// (e.g. Android profile builds); swapped in for the Firebase-backed reporter
/// during DI setup so call sites never have to care.
class NoOpAnalyticsReporter implements AnalyticsReporter {
  @override
  Future<void> logEvent({required AnalyticsEvent event}) async {}
}
