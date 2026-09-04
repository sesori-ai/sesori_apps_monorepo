import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:singular_flutter_sdk/singular_config.dart";

import "singular/singular_static_adapter.dart";

/// Starts Singular's install/session attribution without coupling it to
/// account-linked Sesori product analytics.
@lazySingleton
class SingularAttributionStartup({required final SingularStaticAdapter _singular}) {
  bool _isStarted = false;
  SingularConfig? _pendingCrawlGateConfig;
  SingularConfig? _deferredStartConfig;

  bool get isStarted => _isStarted;

  /// Prepares SDK configuration without starting Singular. The asynchronous
  /// crawl-gate decision can then complete after the first frame.
  void prepare({
    required bool isSupportedPlatform,
    required AnalyticsRuntimeDisabledReason? ineligibilityReason,
    required String sdkKey,
    required String sdkSecret,
  }) {
    if (!isSupportedPlatform || ineligibilityReason != null) return;

    _pendingCrawlGateConfig = SingularConfig(sdkKey, sdkSecret)
      // Preserve Sesori's existing no-advertising-identifier boundary. Singular
      // can still perform privacy-preserving install attribution without IDFA/GAID.
      ..limitAdvertisingIdentifiers = true
      // Partner data sharing is allowed for campaign attribution. Sesori still
      // withholds advertising identifiers and sends no custom event properties.
      ..limitDataSharing = false
      ..skAdNetworkEnabled = true
      ..enableLogging = false;
  }

  void applyCrawlGate({required AnalyticsStoreCrawlGate crawlGate}) {
    if (_isStarted) return;
    final config = _pendingCrawlGateConfig;
    if (config == null) return;

    if (crawlGate == AnalyticsStoreCrawlGate.suspend) {
      _pendingCrawlGateConfig = null;
      _deferredStartConfig = config;
      logi("Singular attribution deferred until interactive authentication");
      return;
    }

    if (_start(config: config)) {
      _pendingCrawlGateConfig = null;
      logi("Singular attribution started");
    }
  }

  bool activateAfterInteractiveAuthentication() {
    if (_isStarted) return true;
    final config = _deferredStartConfig ?? _pendingCrawlGateConfig;
    if (config == null || !_start(config: config)) return false;

    _pendingCrawlGateConfig = null;
    _deferredStartConfig = null;
    logi("Singular attribution started after interactive authentication");
    return true;
  }

  bool _start({required SingularConfig config}) {
    try {
      _singular.start(config: config);
    } on Object catch (error, stackTrace) {
      logw("Failed to start Singular attribution", error, stackTrace);
      return false;
    }
    _isStarted = true;
    return true;
  }
}
