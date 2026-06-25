import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../capabilities/notifications/register_token_request.dart";

@lazySingleton
class NotificationApi {
  final AuthenticatedHttpApiClient _client;

  NotificationApi({required AuthenticatedHttpApiClient client}) : _client = client;

  Future<void> registerToken({required RegisterTokenRequest request}) async {
    final response = await _client.post(
      Uri.parse("$authBaseUrl/notifications/register-token"),
      fromJson: (_) => true,
      body: request.toJson(),
    );

    _throwIfError(response);
  }

  Future<void> unregisterToken({required String token}) async {
    final encodedToken = Uri.encodeComponent(token);
    final response = await _client.delete(
      Uri.parse("$authBaseUrl/notifications/tokens/$encodedToken"),
      fromJson: (_) => true,
    );

    _throwIfError(response);
  }

  void _throwIfError<T>(ApiResponse<T> response) {
    if (response case ErrorResponse<T>(error: final error)) {
      throw error;
    }
  }
}
