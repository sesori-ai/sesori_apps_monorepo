import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:singular_flutter_sdk/singular_config.dart";

import "singular/singular_static_adapter.dart";

enum SingularAttributionStartupStatus() {
  started,
  unsupportedPlatform,
  ineligibleBuild,
  missingCredentials,
  invalidCredentials,
  failed,
}

/// Starts Singular's install/session attribution without coupling it to
/// account-linked Sesori product analytics.
class const SingularAttributionStartup({required final SingularStaticAdapter _singular}) {
  SingularAttributionStartupStatus start({
    required bool isSupportedPlatform,
    required bool isEligibleBuild,
    required String? sdkKey,
    required String? sdkSecret,
  }) {
    if (!isSupportedPlatform) return SingularAttributionStartupStatus.unsupportedPlatform;
    if (!isEligibleBuild) return SingularAttributionStartupStatus.ineligibleBuild;
    if (sdkKey == null && sdkSecret == null) return SingularAttributionStartupStatus.missingCredentials;
    if (sdkKey == null || sdkSecret == null) return SingularAttributionStartupStatus.invalidCredentials;

    final config = SingularConfig(sdkKey, sdkSecret)
      // Preserve Sesori's existing no-advertising-identifier boundary. Singular
      // can still perform privacy-preserving install attribution without IDFA/GAID.
      ..limitAdvertisingIdentifiers = true
      // Partner data sharing remains limited until Sesori has a dedicated
      // attribution-consent design approved for release.
      ..limitDataSharing = true
      ..skAdNetworkEnabled = true
      ..enableLogging = false;

    try {
      _singular.start(config: config);
      return SingularAttributionStartupStatus.started;
    } on Object catch (error, stackTrace) {
      logw("Failed to start Singular attribution", error, stackTrace);
      return SingularAttributionStartupStatus.failed;
    }
  }
}
