import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_shared/sesori_shared.dart";

const String oauthSessionTokenHeader = "X-Sesori-Session-Token";
const Duration _bridgeRegistrationDeadline = Duration(seconds: 15);

typedef AuthRequestSender = Future<http.Response> Function({
  required http.Client client,
  required String method,
  required Uri url,
  required Map<String, String>? headers,
  required String? body,
  required Duration deadline,
});

class AuthApiException({
  required final String method,
  required final Uri uri,
  required final int statusCode,
  required final String body,
}) implements Exception {
  @override
  String toString() => "AuthApiException: $method $uri returned status $statusCode";
}

class BridgeRegistrationException({required final int statusCode, required String body}) implements Exception {
  final String message = "BridgeRegistrationException: status $statusCode | body $body";

  @override
  String toString() => message;
}

class AuthApi({
  required final String authBackendUrl,
  required final http.Client _client,
  required final Duration _requestDeadline,
  required final AuthRequestSender _sendRequest,
}) {
  static const Duration defaultRequestDeadline = Duration(seconds: 35);

  Uri _uri(String path) => Uri.parse("$authBackendUrl/$path");

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
    final response = await _sendRequest(
      client: _client,
      method: "POST",
      url: _uri("auth/bridges"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $accessToken",
      },
      body: jsonEncode(RegisterBridgeRequest(name: name, platform: platform, bridgeId: bridgeId).toJson()),
      deadline: _bridgeRegistrationDeadline,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw BridgeRegistrationException(statusCode: response.statusCode, body: response.body);
    }
    return BridgeSummary.fromJson(jsonDecodeMap(response.body));
  }

  Future<void> deleteBridge({required String bridgeId, required String accessToken}) async {
    final response = await _sendRequest(
      client: _client,
      method: "DELETE",
      url: _uri("auth/bridges/${Uri.encodeComponent(bridgeId)}"),
      headers: {"Authorization": "Bearer $accessToken"},
      body: null,
      deadline: _bridgeRegistrationDeadline,
    );
    if (response.statusCode != 200) {
      throw BridgeRegistrationException(statusCode: response.statusCode, body: response.body);
    }
  }

  Future<AuthMeResponse> getCurrentUser({required String accessToken}) async {
    final uri = _uri("auth/me");
    final response = await _sendRequest(
      client: _client,
      method: "GET",
      url: uri,
      headers: {"Authorization": "Bearer $accessToken"},
      body: null,
      deadline: _requestDeadline,
    );
    if (response.statusCode != 200) {
      throw AuthApiException(method: "GET", uri: uri, statusCode: response.statusCode, body: response.body);
    }
    return AuthMeResponse.fromJson(jsonDecodeMap(response.body));
  }

  Future<AuthResponse> refreshToken({
    required String refreshToken,
  }) async {
    final uri = _uri("auth/refresh");
    final response = await _sendRequest(
      client: _client,
      method: "POST",
      url: uri,
      headers: const {"Content-Type": "application/json"},
      body: jsonEncode({"refreshToken": refreshToken}),
      deadline: _requestDeadline,
    );
    if (response.statusCode != 200) {
      throw AuthApiException(method: "POST", uri: uri, statusCode: response.statusCode, body: response.body);
    }
    final authResponse = AuthResponse.fromJson(jsonDecodeMap(response.body));
    if (authResponse.accessToken.isEmpty || authResponse.refreshToken.isEmpty) {
      throw Exception("refresh response missing tokens");
    }
    return authResponse;
  }
}
