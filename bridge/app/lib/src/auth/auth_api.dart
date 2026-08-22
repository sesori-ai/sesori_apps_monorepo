import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_shared/sesori_shared.dart";

import "../foundation/abortable_request_client.dart";
import "../foundation/auth_backend_url.dart";

const String oauthSessionTokenHeader = "X-Sesori-Session-Token";
const Duration _bridgeRegistrationDeadline = Duration(seconds: 15);

class BridgeRegistrationException({required final int statusCode, required String body}) implements Exception {
  final String message = "BridgeRegistrationException: status $statusCode | body $body";

  @override
  String toString() => message;
}

sealed class const TokenValidationResult();

final class const TokenValidationValid({
  required final String accessToken,
  required final String refreshToken,
}) extends TokenValidationResult;

final class const TokenValidationInvalid() extends TokenValidationResult;

class AuthApi({
  required String authBackendUrl,
  required final http.Client _client,
  required final AbortableRequestClient _requestClient,
}) {
  final String _authBackendUrl = normalizeAuthBackendUrl(url: authBackendUrl);

  Uri _uri(String path) => Uri.parse("$_authBackendUrl/$path");

  Future<AuthInitResponse> initOAuthSession({
    required OAuthProvider provider,
    required String sessionToken,
    required AuthClientType clientType,
    required DeviceInfo device,
  }) async {
    final uri = _uri("${provider.apiAuthPath}/init");
    final response = await _client.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        oauthSessionTokenHeader: sessionToken,
      },
      body: jsonEncode(AuthInitRequest(clientType: clientType, device: device).toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception("init ${provider.label} auth failed: status ${response.statusCode}");
    }

    final AuthInitResponse initResp;
    try {
      initResp = AuthInitResponse.fromJson(jsonDecodeMap(response.body));
    } on Object catch (e) {
      throw Exception("auth init response malformed: $e");
    }

    if (initResp.authUrl.isEmpty || initResp.state.isEmpty) {
      throw Exception("auth init response missing authUrl/state");
    }

    return initResp;
  }

  Future<AuthSessionStatusResponse> getOAuthSessionStatus({required String sessionToken}) async {
    final uri = _uri("auth/session/status");
    final response = await _client.get(
      uri,
      headers: {oauthSessionTokenHeader: sessionToken},
    );

    if (response.statusCode == 200 || response.statusCode == 410) {
      return AuthSessionStatusResponse.fromJson(jsonDecodeMap(response.body));
    }

    throw Exception("auth session status failed: status ${response.statusCode}");
  }

  Future<void> ackOAuthSessionCompletion({required String sessionToken}) async {
    final uri = _uri("auth/session/status/ack");
    final response = await _client.post(
      uri,
      headers: {oauthSessionTokenHeader: sessionToken},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception("auth session ACK failed: status ${response.statusCode}");
    }
  }

  Future<BridgeSummary> registerBridge({
    required String name,
    required String platform,
    required String? bridgeId,
    required String accessToken,
  }) async {
    final response = await _requestClient.send(
      client: _client,
      method: "POST",
      url: _uri("auth/bridges"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $accessToken",
      },
      body: jsonEncode(RegisterBridgeRequest(name: name, platform: platform, bridgeId: bridgeId).toJson()),
      deadline: _bridgeRegistrationDeadline,
      abortSignal: null,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw BridgeRegistrationException(statusCode: response.statusCode, body: response.body);
    }
    return BridgeSummary.fromJson(jsonDecodeMap(response.body));
  }

  Future<void> deleteBridge({required String bridgeId, required String accessToken}) async {
    final response = await _requestClient.send(
      client: _client,
      method: "DELETE",
      url: _uri("auth/bridges/${Uri.encodeComponent(bridgeId)}"),
      headers: {"Authorization": "Bearer $accessToken"},
      body: null,
      deadline: _bridgeRegistrationDeadline,
      abortSignal: null,
    );
    if (response.statusCode != 200) {
      throw BridgeRegistrationException(statusCode: response.statusCode, body: response.body);
    }
  }

  Future<String> fetchUsername({required String accessToken}) async {
    final response = await _client.get(
      _uri("auth/me"),
      headers: {"Authorization": "Bearer $accessToken"},
    );
    if (response.statusCode != 200) {
      throw Exception("auth me returned status ${response.statusCode}");
    }
    final authMeResponse = AuthMeResponse.fromJson(jsonDecodeMap(response.body));
    return authMeResponse.user.providerUsername ?? "unknown-user";
  }

  Future<TokenValidationResult> validateToken({
    required String accessToken,
    required String refreshToken,
  }) async {
    final meResponse = await _client.get(
      _uri("auth/me"),
      headers: {"Authorization": "Bearer $accessToken"},
    );
    if (meResponse.statusCode == 200) {
      return TokenValidationValid(accessToken: accessToken, refreshToken: refreshToken);
    }
    if (meResponse.statusCode != 401) {
      return const TokenValidationInvalid();
    }

    final refreshResponse = await _client.post(
      _uri("auth/refresh"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"refreshToken": refreshToken}),
    );
    if (refreshResponse.statusCode != 200) {
      return const TokenValidationInvalid();
    }
    final authResponse = AuthResponse.fromJson(jsonDecodeMap(refreshResponse.body));
    if (authResponse.accessToken.isEmpty || authResponse.refreshToken.isEmpty) {
      throw Exception("refresh response missing tokens");
    }
    return TokenValidationValid(
      accessToken: authResponse.accessToken,
      refreshToken: authResponse.refreshToken,
    );
  }
}
