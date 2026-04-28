import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_shared/sesori_shared.dart";

class EmailAuthApi {
  final String authBackendUrl;

  EmailAuthApi({required this.authBackendUrl});

  Future<AuthResponse> loginWithEmail(String email, String password) async {
    final base = authBackendUrl.endsWith("/")
        ? authBackendUrl.substring(0, authBackendUrl.length - 1)
        : authBackendUrl;
    final uri = Uri.parse("$base/auth/password/login");

    final body = jsonEncode({"email": email, "password": password});

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EmailAuthApiException(response.statusCode, response.body);
    }

    return AuthResponse.fromJson(jsonDecodeMap(response.body));
  }
}

class EmailAuthApiException implements Exception {
  final int statusCode;
  final String body;

  EmailAuthApiException(this.statusCode, this.body);

  @override
  String toString() => "EmailAuthApiException: status $statusCode";
}
