import "dart:async";

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

    return await _enableCollection();
  }

  /// Lifts the build-window suspension once [authStates] reports a signed-in
  /// user, proving this process is a person rather than a store crawl. Only the
  /// SDK's own measurement resumes; the process-wide runtime capability was
  /// already published as disabled, so Sesori-defined events stay off until the
  /// next launch.
  void enableOnceAuthenticated({required Stream<AuthState> authStates}) {
    unawaited(
      authStates.firstWhere((state) => state is AuthAuthenticated).then((_) async {
        final capability = await _enableCollection();
        if (capability.isEnabled) {
          logi("Firebase analytics collection enabled after authentication inside the build window");
        }
      }),
    );
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
