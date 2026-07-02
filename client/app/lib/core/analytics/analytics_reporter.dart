// ignore_for_file: no_slop_linter/prefer_specific_type -- analytics parameter
// values are string-or-number by the GA4 contract, mirroring
// FirebaseAnalytics.logEvent's own Map<String, Object> signature.

/// Product-analytics seam for user-action events, so feature code depends on
/// this interface (resolved through DI) instead of a concrete analytics SDK.
///
/// Event names and parameter keys live in `AnalyticsEvents`; add new events
/// there rather than inlining string literals at call sites.
abstract interface class AnalyticsReporter {
  /// Logs a single user-action event.
  ///
  /// Best-effort by contract: implementations must swallow (and log) delivery
  /// failures so a broken analytics backend can never surface to the user.
  Future<void> logEvent({required String name, required Map<String, Object>? parameters});
}
