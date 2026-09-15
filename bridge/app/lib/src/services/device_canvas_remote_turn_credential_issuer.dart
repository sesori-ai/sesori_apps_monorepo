import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";

import "../auth/auth_api.dart";
import "../auth/bridge_id_provider.dart";
import "../auth/token_refresher.dart";
import "device_canvas_turn_credential_issuer.dart";

typedef DeviceCanvasTurnCredentialRequest = Future<DeviceCanvasTurnConfiguration> Function({
  required String bridgeId,
  required String operationId,
  required int leaseExpiresAt,
  required String accessToken,
});

class const DeviceCanvasTurnCredentialIssuanceException(final String reason) implements Exception {
  @override
  String toString() => "DeviceCanvasTurnCredentialIssuanceException: $reason";
}

class DeviceCanvasRemoteTurnCredentialIssuer({
  required final DeviceCanvasTurnCredentialRequest _requestCredentials,
  required final TokenRefresher _tokenRefresher,
  required final BridgeIdProvider _bridgeIdProvider,
}) implements DeviceCanvasTurnCredentialIssuer {
  static final RegExp _operationIdPattern = RegExp(r"^[A-Za-z0-9_-]+$");

  @override
  Future<DeviceCanvasTurnConfiguration> issue({
    required String operationId,
    required int leaseExpiresAt,
    required DateTime now,
  }) async {
    final bridgeId = _bridgeIdProvider.bridgeId;
    if (bridgeId == null) {
      throw const DeviceCanvasTurnCredentialIssuanceException("bridge is not registered");
    }
    if (operationId.isEmpty ||
        operationId.length > maxDeviceCanvasStreamOperationIdLength ||
        !_operationIdPattern.hasMatch(operationId) ||
        leaseExpiresAt <= now.millisecondsSinceEpoch) {
      throw const DeviceCanvasTurnCredentialIssuanceException("request is invalid");
    }

    final accessToken = await _tokenRefresher.getAccessToken();
    DeviceCanvasTurnConfiguration configuration;
    try {
      configuration = await _request(
        bridgeId: bridgeId,
        operationId: operationId,
        leaseExpiresAt: leaseExpiresAt,
        accessToken: accessToken,
      );
    } on DeviceCanvasTurnApiException catch (error) {
      if (error.statusCode != 401) rethrow;
      final refreshedToken = await _tokenRefresher.getAccessToken(forceRefresh: true);
      configuration = await _request(
        bridgeId: bridgeId,
        operationId: operationId,
        leaseExpiresAt: leaseExpiresAt,
        accessToken: refreshedToken,
      );
    }

    if (_bridgeIdProvider.bridgeId != bridgeId ||
        !_isValidResponse(
          configuration: configuration,
          operationId: operationId,
          leaseExpiresAt: leaseExpiresAt,
          now: now,
        )) {
      throw const DeviceCanvasTurnCredentialIssuanceException("response is invalid");
    }
    return configuration;
  }

  Future<DeviceCanvasTurnConfiguration> _request({
    required String bridgeId,
    required String operationId,
    required int leaseExpiresAt,
    required String accessToken,
  }) {
    if (_bridgeIdProvider.bridgeId != bridgeId) {
      throw const DeviceCanvasTurnCredentialIssuanceException("bridge registration changed");
    }
    return _requestCredentials(
      bridgeId: bridgeId,
      operationId: operationId,
      leaseExpiresAt: leaseExpiresAt,
      accessToken: accessToken,
    );
  }

  static bool _isValidResponse({
    required DeviceCanvasTurnConfiguration configuration,
    required String operationId,
    required int leaseExpiresAt,
    required DateTime now,
  }) {
    if (!configuration.isValid ||
        configuration.expiresAt % Duration.millisecondsPerSecond != 0 ||
        configuration.expiresAt <= now.millisecondsSinceEpoch ||
        configuration.expiresAt > leaseExpiresAt ||
        configuration.username != "${configuration.expiresAt ~/ Duration.millisecondsPerSecond}:$operationId" ||
        configuration.urls.any((url) => !isCanonicalDeviceCanvasDnsTurnUrl(url))) {
      return false;
    }

    try {
      final decoded = base64Decode(configuration.credential);
      return decoded.length == 20 && base64Encode(decoded) == configuration.credential;
    } on FormatException {
      return false;
    }
  }
}
