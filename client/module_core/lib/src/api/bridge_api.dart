import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Layer 1 access to the auth server's bridge endpoints.
@lazySingleton
class BridgeApi {
  final AuthenticatedHttpApiClient _client;

  BridgeApi({required AuthenticatedHttpApiClient client}) : _client = client;

  /// Fetches the bridges registered with the authenticated account
  /// (`GET /auth/bridges`).
  Future<ApiResponse<BridgesListResponse>> fetchRegisteredBridges() {
    return _client.get(
      Uri.parse("$authBaseUrl/auth/bridges"),
      fromJson: _parseBridges,
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
}
