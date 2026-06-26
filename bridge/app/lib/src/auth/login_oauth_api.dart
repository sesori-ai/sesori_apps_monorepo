import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_shared/sesori_shared.dart";

const String oauthSessionTokenHeader = "X-Sesori-Session-Token";

Uri _buildUri({required String base, required String path}) {
  final b = base.endsWith("/") ? base.substring(0, base.length - 1) : base;
  return Uri.parse("$b/$path");
}

class LoginOAuthApi {
  final String authBackendUrl;
  final http.Client _client;
  final String _clientType;
  final DeviceInfo _device;

  LoginOAuthApi({
    required this.authBackendUrl,
    required http.Client client,
    required String clientType,
    required DeviceInfo device,
  })  : _client = client,
        _clientType = clientType,
        _device = device;

  Future<AuthInitResponse> initOAuthSession({
    required OAuthProvider provider,
    required String sessionToken,
  }) async {
    final uri = _buildUri(base: authBackendUrl, path: "${provider.apiAuthPath}/init");
    final response = await _client.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        oauthSessionTokenHeader: sessionToken,
      },
      body: jsonEncode(AuthInitRequest(clientType: _clientType, device: _device).toJson()),
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
    final uri = _buildUri(base: authBackendUrl, path: "auth/session/status");
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
    final uri = _buildUri(base: authBackendUrl, path: "auth/session/status/ack");
    final response = await _client.post(
      uri,
      headers: {oauthSessionTokenHeader: sessionToken},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception("auth session ACK failed: status ${response.statusCode}");
    }
  }
}
