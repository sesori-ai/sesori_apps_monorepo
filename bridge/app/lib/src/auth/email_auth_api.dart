import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_shared/sesori_shared.dart";

class EmailAuthApi {
  final String authBackendUrl;

  EmailAuthApi({required this.authBackendUrl});

  Future<AuthResponse> loginWithEmail({required String email, required String password}) async {
    final base = authBackendUrl.endsWith("/") ? authBackendUrl.substring(0, authBackendUrl.length - 1) : authBackendUrl;
    final uri = Uri.parse("$base/${AuthProvider.email.apiAuthPath}");

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

abstract class EmailLoginException implements Exception {
  String get message;
}

class EmailAuthApiException implements EmailLoginException {
  final int statusCode;
  final String body;

  @override
  final String message;

  EmailAuthApiException({required this.statusCode, required this.body})
    : message = "EmailAuthApiException: status $statusCode | body $body";

  @override
  String toString() => message;
}

class EmailLoginExceptionImpl implements EmailLoginException {
  @override
  final String message;

  EmailLoginExceptionImpl(this.message);

  @override
  String toString() => "EmailLoginException: $message";
}

class RateLimitException implements EmailLoginException {
  @override
  final String message;

  RateLimitException([this.message = "Rate limit exceeded. Please try again later."]);

  @override
  String toString() => "RateLimitException: $message";
}
