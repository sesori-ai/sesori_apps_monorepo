import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_shared/sesori_shared.dart";

const Duration _requestTimeout = Duration(seconds: 15);

/// Raised when an `/auth/bridges` request returns a non-success status.
class BridgeRegistrationException({required final int statusCode, required String body}) implements Exception {
  final String message = "BridgeRegistrationException: status $statusCode | body $body";

  @override
  String toString() => message;
}

class BridgeRegistrationApi({
  required String authBackendUrl,
  required final http.Client _client,
}) {
  final String _authBackendUrl = authBackendUrl.endsWith("/")
      ? authBackendUrl.substring(0, authBackendUrl.length - 1)
      : authBackendUrl;

  /// Registers (or re-registers) this bridge via `POST /auth/bridges`.
  ///
  /// When [bridgeId] identifies an existing bridge owned by the calling user
  /// the server updates and returns it (200); otherwise the server mints a
  /// fresh bridge id (201). Throws [BridgeRegistrationException] on any other
  /// status.
  Future<BridgeSummary> registerBridge({
    required String name,
    required String platform,
    required String? bridgeId,
    required String accessToken,
  }) async {
    final request = RegisterBridgeRequest(name: name, platform: platform, bridgeId: bridgeId);

    final response = await _client
        .post(
          Uri.parse("$_authBackendUrl/auth/bridges"),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $accessToken",
          },
          body: jsonEncode(request.toJson()),
        )
        .timeout(_requestTimeout);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw BridgeRegistrationException(statusCode: response.statusCode, body: response.body);
    }

    return BridgeSummary.fromJson(jsonDecodeMap(response.body));
  }

  /// Removes this bridge's registration via `DELETE /auth/bridges/:bridgeId`.
  ///
  /// Throws [BridgeRegistrationException] on any non-200 status (including
  /// 404 when the bridge is unknown or already revoked).
  Future<void> deleteBridge({
    required String bridgeId,
    required String accessToken,
  }) async {
    final response = await _client
        .delete(
          Uri.parse("$_authBackendUrl/auth/bridges/${Uri.encodeComponent(bridgeId)}"),
          headers: {"Authorization": "Bearer $accessToken"},
        )
        .timeout(_requestTimeout);

    if (response.statusCode != 200) {
      throw BridgeRegistrationException(statusCode: response.statusCode, body: response.body);
    }
  }
}
