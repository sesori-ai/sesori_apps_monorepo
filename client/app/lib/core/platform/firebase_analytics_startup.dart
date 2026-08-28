import "package:firebase_analytics/firebase_analytics.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../di/firebase_register_module.dart";

@firebaseEnabledEnvironment
@lazySingleton
class FirebaseAnalyticsStartup({required final FirebaseAnalytics _analytics}) {
  bool _isSuspendedForStoreCrawl = false;

  /// Configures the Firebase analytics SDK for this process and reports the
  /// resulting runtime capability. [ineligibilityReason] states why this
  /// process must never report, or is null when it may.
  ///
  /// [suspendForStoreCrawl] keeps the SDK's own collection off for an eligible
  /// process that may be a Play pre-launch crawl. The Sesori runtime stays
  /// operational — its events are simply discarded by the suspended SDK — and
  /// [activateAfterInteractiveAuthentication] lifts the suspension once a
  /// person proves they are using this process.
  Future<AnalyticsRuntimeCapability> configure({
    required AnalyticsRuntimeDisabledReason? ineligibilityReason,
    required bool suspendForStoreCrawl,
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

    if (suspendForStoreCrawl) {
      _isSuspendedForStoreCrawl = true;
      logi("Firebase analytics collection suspended for a possible store crawl");
      return const AnalyticsRuntimeCapability.enabled();
    }

    return await _enableCollection();
  }

  /// Lifts the store-crawl suspension for the rest of this process; a no-op
  /// when nothing is suspended. Best-effort: a failure keeps the SDK
  /// suspended, which discards subsequent events instead of blocking callers.
  Future<void> activateAfterInteractiveAuthentication() async {
    if (!_isSuspendedForStoreCrawl) return;
    final capability = await _enableCollection();
    if (capability.isEnabled) {
      _isSuspendedForStoreCrawl = false;
      logi("Firebase analytics collection enabled after interactive authentication");
    }
  }

  Future<AnalyticsRuntimeCapability> _enableCollection() async {
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
