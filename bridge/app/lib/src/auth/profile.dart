import "package:http/http.dart" as http;
import "package:sesori_shared/sesori_shared.dart";

/// Fetches the authenticated user's GitHub username from [authBackendURL]/auth/me.
///
/// Returns `user.providerUsername` from the response, or `"unknown-user"` if
/// the field is missing or empty.
///
/// Throws an [Exception] if the HTTP request fails or returns a non-200 status.
Future<String> fetchUsername(String authBackendURL, String accessToken) async {
  final base = authBackendURL.endsWith("/") ? authBackendURL.substring(0, authBackendURL.length - 1) : authBackendURL;
  final uri = Uri.parse("$base/auth/me");

  final response = await http.get(
    uri,
    headers: {"Authorization": "Bearer $accessToken"},
  );

  if (response.statusCode != 200) {
    throw Exception("auth me returned status ${response.statusCode}");
  }

  final authMeResponse = AuthMeResponse.fromJson(jsonDecodeMap(response.body));
  return authMeResponse.user.providerUsername ?? "unknown-user";
}
