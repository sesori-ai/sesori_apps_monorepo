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
  DesktopFirebaseSdk? _activeSdk;

  /// Called only after primary-process admission, before login can emit events.
  Future<void> initialize({required TargetPlatform platform}) async {
    // Firebase Analytics supports macOS, but not native Windows or Linux.
    // The shared capability already excludes debug/profile and source builds.
    if (platform != TargetPlatform.macOS || !_capability.isEnabled) return;
    try {
      await _sdk.initialize();
      _activeSdk = _sdk;
    } on Object catch (error, stackTrace) {
      logw("Failed to initialize desktop Firebase analytics", error, stackTrace);
    }
  }

  Future<void> logInstallationEvent({required InstallationAnalyticsEvent event}) async {
    final sdk = _activeSdk;
    if (sdk == null) return;
    try {
      await sdk.logInstallationEvent(event: event);
    } on Object catch (error, stackTrace) {
      logw("Failed to report desktop authentication analytics (${event.wireName})", error, stackTrace);
    }
  }
}
