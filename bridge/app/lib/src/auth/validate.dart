import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_shared/sesori_shared.dart";

/// Validated (and possibly refreshed) credentials.
///
/// Deliberately not a TokenData: validation never knows the bridge id, so
/// this type cannot be persisted raw — callers merge it with persisted state.
class TokenValidationResult {
  final String accessToken;
  final String refreshToken;

  /// True if the credentials are valid (either original or refreshed);
  /// false if both access and refresh failed (credentials may be revoked).
  final bool isValid;

  TokenValidationResult({
    required this.accessToken,
    required this.refreshToken,
    required this.isValid,
  });
}

/// Validates an access token and attempts refresh if expired.
///
/// Throws on network/parsing errors.
Future<TokenValidationResult> validateToken({
  required String authBackendURL,
  required String accessToken,
  required String refreshToken,
}) async {
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
    return TokenValidationResult(
      accessToken: accessToken,
      refreshToken: refreshToken,
      isValid: true,
    );
  }

  // If not 401, return invalid (but no error)
  if (meResponse.statusCode != 401) {
    return TokenValidationResult(
      accessToken: accessToken,
      refreshToken: refreshToken,
      isValid: false,
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

  // If refresh failed, return original tokens as invalid
  if (refreshResponse.statusCode != 200) {
    return TokenValidationResult(
      accessToken: accessToken,
      refreshToken: refreshToken,
      isValid: false,
    );
  }

  // Parse refresh response
  late AuthResponse refreshed;
  try {
    refreshed = AuthResponse.fromJson(jsonDecodeMap(refreshResponse.body));
  } catch (e) {
    throw Exception("decode refresh response: $e");
  }

  // Validate tokens are present
  if (refreshed.accessToken.isEmpty || refreshed.refreshToken.isEmpty) {
    throw Exception("refresh response missing tokens");
  }

  // Return new tokens as valid
  return TokenValidationResult(
    accessToken: refreshed.accessToken,
    refreshToken: refreshed.refreshToken,
    isValid: true,
  );
}
