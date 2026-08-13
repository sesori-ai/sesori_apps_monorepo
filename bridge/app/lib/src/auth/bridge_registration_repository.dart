import "package:sesori_shared/sesori_shared.dart";

import "bridge_registration_api.dart";

/// Repository over the auth server's `/auth/bridges` endpoints.
class BridgeRegistrationRepository({required final BridgeRegistrationApi _api}) {
  /// Registers (or re-registers) this bridge and returns its [BridgeSummary].
  Future<BridgeSummary> register({
    required String name,
    required String platform,
    required String? bridgeId,
    required String accessToken,
  }) {
    return _api.registerBridge(
      name: name,
      platform: platform,
      bridgeId: bridgeId,
      accessToken: accessToken,
    );
  }

  /// Removes the registration identified by [bridgeId].
  Future<void> unregister({
    required String bridgeId,
    required String accessToken,
  }) {
    return _api.deleteBridge(bridgeId: bridgeId, accessToken: accessToken);
  }
}
