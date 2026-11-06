import "package:firebase_analytics/firebase_analytics.dart";
import "package:flutter/foundation.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "desktop_firebase_sdk.dart";

/// Adds native usage/session and account-less authentication reporting to
/// Firebase. Account-linked product events keep their existing server path.
@lazySingleton
class DesktopFirebaseAnalytics({
  required final DesktopFirebaseSdk _sdk,
  required final AnalyticsRuntimeCapability _capability,
}) {
  FirebaseAnalytics? _analytics;

  /// Called only after primary-process admission, before login can emit events.
  Future<void> initialize({required TargetPlatform platform}) async {
    // FlutterFire Analytics supports macOS, but not native Windows or Linux.
    // The shared capability already excludes debug/profile and source builds.
    if (platform != TargetPlatform.macOS || !_capability.isEnabled) return;
    try {
      final analytics = await _sdk.initialize();
      await analytics.setAnalyticsCollectionEnabled(false);
      await analytics.setConsent(
        adPersonalizationSignalsConsentGranted: false,
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        personalizationStorageConsentGranted: false,
        securityStorageConsentGranted: false,
        analyticsStorageConsentGranted: true,
        functionalityStorageConsentGranted: true,
      );
      await analytics.setAnalyticsCollectionEnabled(true);
      _analytics = analytics;
    } on Object catch (error, stackTrace) {
      logw("Failed to initialize desktop Firebase analytics", error, stackTrace);
    }
  }

  Future<void> logInstallationEvent({required InstallationAnalyticsEvent event}) async {
    final analytics = _analytics;
    if (analytics == null) return;
    try {
      await analytics.logEvent(
        name: event.wireName,
        parameters: {...event.parameters, "schema_version": 1},
      );
    } on Object catch (error, stackTrace) {
      logw("Failed to report desktop authentication analytics (${event.wireName})", error, stackTrace);
    }
  }
}
