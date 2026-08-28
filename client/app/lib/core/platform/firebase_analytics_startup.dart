import "package:firebase_analytics/firebase_analytics.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../di/firebase_register_module.dart";

enum _FirebaseAnalyticsStartupState() {
  notPrepared,
  disabled,
  waitingForCrawlGate,
  suspendedForStoreCrawl,
  active
}

@firebaseEnabledEnvironment
@lazySingleton
class FirebaseAnalyticsStartup({required final FirebaseAnalytics _analytics}) {
  _FirebaseAnalyticsStartupState _state = _FirebaseAnalyticsStartupState.notPrepared;

  /// Keeps native collection off while preparing the process capability. The
  /// remote crawl-gate decision is applied separately so it cannot delay the
  /// first frame.
  Future<AnalyticsRuntimeCapability> prepare({
    required AnalyticsRuntimeDisabledReason? ineligibilityReason,
  }) async {
    try {
      // Native configuration starts fresh installs off. Enforce that decision
      // for every process before any custom analytics source starts.
      await _analytics.setAnalyticsCollectionEnabled(false);
    } on Object catch (error, stackTrace) {
      _state = _FirebaseAnalyticsStartupState.disabled;
      logw("Failed to suspend Firebase analytics collection during startup", error, stackTrace);
      return const AnalyticsRuntimeCapability.disabled(
        reason: AnalyticsRuntimeDisabledReason.analyticsSinkUnavailable,
      );
    }

    if (ineligibilityReason case final reason?) {
      _state = _FirebaseAnalyticsStartupState.disabled;
      return AnalyticsRuntimeCapability.disabled(reason: reason);
    }

    _state = _FirebaseAnalyticsStartupState.waitingForCrawlGate;
    return const AnalyticsRuntimeCapability.enabled();
  }

  /// Enables collection or leaves it suspended after the asynchronous store
  /// crawl decision. Interactive authentication may activate collection first;
  /// in that case the later gate result cannot suspend the proven-human process.
  Future<void> applyCrawlGate({required AnalyticsStoreCrawlGate crawlGate}) async {
    if (_state != _FirebaseAnalyticsStartupState.waitingForCrawlGate) return;
    if (crawlGate == AnalyticsStoreCrawlGate.suspend) {
      _state = _FirebaseAnalyticsStartupState.suspendedForStoreCrawl;
      logi("Firebase analytics collection suspended for a possible store crawl");
      return;
    }

    await _activateCollection();
  }

  /// Lifts a pending or resolved store-crawl suspension for the rest of this
  /// process. Best-effort: a failure keeps the SDK suspended, which discards
  /// subsequent events instead of blocking callers.
  Future<void> activateAfterInteractiveAuthentication() async {
    if (_state != _FirebaseAnalyticsStartupState.waitingForCrawlGate &&
        _state != _FirebaseAnalyticsStartupState.suspendedForStoreCrawl) {
      return;
    }
    if (await _activateCollection()) {
      logi("Firebase analytics collection enabled after interactive authentication");
    }
  }

  Future<bool> _activateCollection() async {
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
      _state = _FirebaseAnalyticsStartupState.active;
      return true;
    } on Object catch (error, stackTrace) {
      logw("Failed to enable Firebase analytics collection", error, stackTrace);
      return false;
    }
  }
}
