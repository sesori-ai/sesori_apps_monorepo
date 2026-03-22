import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

@lazySingleton
class NotificationApiClient {
  final AuthenticatedHttpApiClient _client;

  NotificationApiClient(AuthenticatedHttpApiClient client) : _client = client;

  Future<void> registerToken({required String token, required String platform}) async {
    final response = await _client.post(
      Uri.parse("$authBaseUrl/notifications/register-token"),
      fromJson: (_) => true,
      body: {
        "token": token,
        "platform": platform,
      },
    );

    _throwIfError(response);
  }

  Future<void> unregisterToken(String token) async {
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
