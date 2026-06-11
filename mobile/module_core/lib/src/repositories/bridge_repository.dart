import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/bridge_api.dart";

/// Layer 2 access to the bridges registered with the user's account.
@lazySingleton
class BridgeRepository {
  final BridgeApi _api;

  BridgeRepository({required BridgeApi api}) : _api = api;

  /// The bridges registered with the user's account, as reported by the auth
  /// server (`/auth/bridges`). An empty list means the user has never set up
  /// a bridge; a non-empty list means a bridge exists but may be offline.
  Future<ApiResponse<List<BridgeSummary>>> getRegisteredBridges() async {
    final response = await _api.fetchRegisteredBridges();
    return switch (response) {
      SuccessResponse(:final data) => ApiResponse.success(data.bridges),
      ErrorResponse(:final error) => ApiResponse.error(error),
    };
  }
}
