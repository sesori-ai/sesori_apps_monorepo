import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_shared/sesori_shared.dart";

import "../foundation/auth_backend_url.dart";

class LoginEmailApi({required String authBackendUrl}) {
  final String authBackendUrl = normalizeAuthBackendUrl(url: authBackendUrl);

  Future<AuthResponse> loginWithEmail({required String email, required String password}) async {
    final uri = Uri.parse("$authBackendUrl/${AuthProvider.email.apiAuthPath}");

    final body = jsonEncode({"email": email, "password": password});

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EmailAuthApiException(statusCode: response.statusCode, body: response.body);
    }

    return AuthResponse.fromJson(jsonDecodeMap(response.body));
  }
}

abstract class EmailLoginException() implements Exception {
  String get message;
}

class EmailAuthApiException({required final int statusCode, required final String body})
    implements EmailLoginException {
  @override
  final String message = "EmailAuthApiException: status $statusCode | body $body";

  @override
  String toString() => message;
}

class EmailLoginExceptionImpl(@override final String message) implements EmailLoginException {
  @override
  String toString() => "EmailLoginException: $message";
}

class RateLimitException([@override final String message = "Rate limit exceeded. Please try again later."])
    implements EmailLoginException {
  @override
  String toString() => "RateLimitException: $message";
}
