import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_shared/sesori_shared.dart";

import "token.dart";

/// Validates an access token and attempts refresh if expired.
///
/// Returns `(TokenData, bool)` where:
/// - bool is `true` if tokens are valid (either original or refreshed)
/// - bool is `false` if both access and refresh failed (credentials may be revoked)
///
/// Throws on network/parsing errors.
Future<(TokenData, bool)> validateToken(
  String authBackendURL,
  String accessToken,
  String refreshToken,
) async {
  // Build /auth/me URL
  final base = authBackendURL.endsWith("/") ? authBackendURL.substring(0, authBackendURL.length - 1) : authBackendURL;
  final meUri = Uri.parse("$base/auth/me");

  // GET /auth/me with Bearer token
  late http.Response meResponse;
  try {
    meResponse = await http.get(
      meUri,
      headers: {"Authorization": "Bearer $accessToken"},
    );
  } catch (e) {
    throw Exception("validate access token: $e");
  }

  // If 200 OK, tokens are valid
  if (meResponse.statusCode == 200) {
    return (
      TokenData(accessToken: accessToken, refreshToken: refreshToken),
      true,
    );
  }

  // If not 401, return false (invalid but no error)
  if (meResponse.statusCode != 401) {
    return (
      TokenData(accessToken: accessToken, refreshToken: refreshToken),
      false,
    );
  }

  // 401: Try to refresh
  final refreshUri = Uri.parse("$base/auth/refresh");
  final refreshBody = jsonEncode({"refreshToken": refreshToken});

  late http.Response refreshResponse;
  try {
    refreshResponse = await http.post(
      refreshUri,
      headers: {"Content-Type": "application/json"},
      body: refreshBody,
    );
  } catch (e) {
    throw Exception("refresh token: $e");
  }

  // If refresh failed, return original tokens with false
  if (refreshResponse.statusCode != 200) {
    return (
      TokenData(accessToken: accessToken, refreshToken: refreshToken),
      false,
    );
  }

  // Parse refresh response
  late AuthResponse refreshed;
  try {
    final jsonBody = jsonDecode(refreshResponse.body) as Map<String, dynamic>;
    refreshed = AuthResponse.fromJson(jsonBody);
  } catch (e) {
    throw Exception("decode refresh response: $e");
  }

  // Validate tokens are present
  if (refreshed.accessToken.isEmpty || refreshed.refreshToken.isEmpty) {
    throw Exception("refresh response missing tokens");
  }

  // Return new tokens with true
  return (
    TokenData(
      accessToken: refreshed.accessToken,
      refreshToken: refreshed.refreshToken,
    ),
    true,
  );
}
