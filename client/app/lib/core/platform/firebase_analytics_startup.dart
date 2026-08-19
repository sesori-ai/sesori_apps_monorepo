import "package:firebase_analytics/firebase_analytics.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "firebase_analytics_identity_migration.dart";

class const FirebaseAnalyticsStartup({required final FirebaseAnalytics _analytics}) {
  Future<AnalyticsRuntimeCapability> configure({
    required AnalyticsRuntimeDisabledReason? disabledReasonAfterSuccess,
  }) async {
    try {
      // Native configuration defaults collection off, and this also suspends an
      // enabled value persisted by an older app process before any migration.
      await _analytics.setAnalyticsCollectionEnabled(false);
    } on Object catch (error, stackTrace) {
      logw("Failed to suspend Firebase analytics collection during startup", error, stackTrace);
      return const AnalyticsRuntimeCapability.disabled(
        reason: AnalyticsRuntimeDisabledReason.analyticsSinkUnavailable,
      );
    }

    final identityCapability = await FirebaseAnalyticsIdentityMigration(
      analytics: _analytics,
    ).clearLegacyIdentity(disabledReasonAfterSuccess: disabledReasonAfterSuccess);
    if (identityCapability is AnalyticsRuntimeDisabled) return identityCapability;

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
      return identityCapability;
    } on Object catch (error, stackTrace) {
      logw("Failed to enable Firebase analytics collection", error, stackTrace);
      return const AnalyticsRuntimeCapability.disabled(
        reason: AnalyticsRuntimeDisabledReason.analyticsSinkUnavailable,
      );
    }
  }
}
