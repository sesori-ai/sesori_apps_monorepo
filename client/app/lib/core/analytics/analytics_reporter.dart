import "analytics_event.dart";

/// Product-analytics seam for user-action events, so feature code depends on
/// this interface (resolved through DI) instead of a concrete analytics SDK.
///
/// The trackable actions form a closed set: add a new [AnalyticsEvent] union
/// case rather than passing event names or parameter maps around.
abstract interface class AnalyticsReporter {
  /// Logs a single user-action [event].
  ///
  /// Best-effort by contract: implementations must swallow (and log) delivery
  /// failures so a broken analytics backend can never surface to the user.
  Future<void> logEvent({required AnalyticsEvent event});
}
