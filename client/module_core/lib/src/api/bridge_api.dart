import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Layer 1 access to the auth server's bridge endpoints.
@lazySingleton
class BridgeApi({required final AuthenticatedHttpApiClient _client}) {
  /// Fetches the bridges registered with the authenticated account
  /// (`GET /auth/bridges`).
  Future<ApiResponse<BridgesListResponse>> fetchRegisteredBridges() {
    return _client.get(
      Uri.parse("$authBaseUrl/auth/bridges"),
      fromJson: _parseBridges,
    );
  }

  /// Revokes one bridge registration. The repository maps an already-revoked
  /// bridge (404) to the idempotent success expected by logout.
  Future<ApiResponse<void>> deleteBridge({required String bridgeId}) {
    return _client.delete(
      Uri.parse("$authBaseUrl/auth/bridges/${Uri.encodeComponent(bridgeId)}"),
      fromJson: (_) {},
    );
  }

  /// Sets or clears (`null`) one bridge's nickname and returns its updated
  /// summary (`PATCH /auth/bridges/:bridgeId`).
  Future<ApiResponse<BridgeSummary>> renameBridge({required String bridgeId, required String? nickname}) {
    return _client.patch(
      Uri.parse("$authBaseUrl/auth/bridges/${Uri.encodeComponent(bridgeId)}"),
      body: {"nickname": nickname},
      fromJson: _parseBridge,
    );
  }

  // ignore: no_slop_linter/prefer_specific_type, JSON parser callback signature requires dynamic input
  static BridgesListResponse _parseBridges(dynamic json) {
    // ignore: no_slop_linter/prefer_specific_type, JSON parsing requires dynamic
    if (json is Map<String, dynamic>) {
      return BridgesListResponse.fromJson(json);
    }
    throw const FormatException("Unexpected /auth/bridges response shape");
  }

  // ignore: no_slop_linter/prefer_specific_type, JSON parser callback signature requires dynamic input
  static BridgeSummary _parseBridge(dynamic json) {
    // ignore: no_slop_linter/prefer_specific_type, JSON parsing requires dynamic
    if (json is Map<String, dynamic>) {
      return BridgeSummary.fromJson(json);
    }
    throw const FormatException("Unexpected /auth/bridges/:bridgeId response shape");
  }
}
