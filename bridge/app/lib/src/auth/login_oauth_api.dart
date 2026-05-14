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

  LoginOAuthApi({
    required this.authBackendUrl,
    required http.Client client,
  }) : _client = client;

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
      body: jsonEncode(const AuthInitRequest(clientType: "bridge").toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception("init ${provider.label} auth failed: status ${response.statusCode}");
    }

    final initResp = AuthInitResponse.fromJson(jsonDecodeMap(response.body));

    if (initResp.authUrl.isEmpty || initResp.state.isEmpty || initResp.userCode.isEmpty) {
      throw Exception("auth init response missing authUrl/state/userCode");
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
}
