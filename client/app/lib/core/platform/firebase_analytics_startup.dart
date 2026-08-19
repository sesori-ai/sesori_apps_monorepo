import "package:firebase_analytics/firebase_analytics.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

class const FirebaseAnalyticsStartup({required final FirebaseAnalytics _analytics}) {
  /// Configures the Firebase analytics SDK for this process and reports the
  /// resulting runtime capability. [ineligibilityReason] states why this
  /// process must not report, or is null when it may.
  Future<AnalyticsRuntimeCapability> configure({
    required AnalyticsRuntimeDisabledReason? ineligibilityReason,
  }) async {
    try {
      // Native configuration starts fresh installs off. Enforce that decision
      // for every process before any custom analytics source starts.
      await _analytics.setAnalyticsCollectionEnabled(false);
    } on Object catch (error, stackTrace) {
      logw("Failed to suspend Firebase analytics collection during startup", error, stackTrace);
      return const AnalyticsRuntimeCapability.disabled(
        reason: AnalyticsRuntimeDisabledReason.analyticsSinkUnavailable,
      );
    }

    if (ineligibilityReason case final reason?) {
      return AnalyticsRuntimeCapability.disabled(reason: reason);
    }

    try {
      await _analytics.setConsent(
        adPersonalizationSignalsConsentGranted: false,
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        personalizationStorageConsentGranted: false,
        securityStorageConsentGranted: false,
        analyticsStorageConsentGranted: true,
        functionalityStorageConsentGranted: true,
      );
      await _analytics.setAnalyticsCollectionEnabled(true);
      return const AnalyticsRuntimeCapability.enabled();
    } on Object catch (error, stackTrace) {
      logw("Failed to enable Firebase analytics collection", error, stackTrace);
      return const AnalyticsRuntimeCapability.disabled(
        reason: AnalyticsRuntimeDisabledReason.analyticsSinkUnavailable,
      );
    }
  }
}
