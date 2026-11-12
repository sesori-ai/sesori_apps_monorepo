import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../capabilities/notifications/register_fid_request.dart";

@lazySingleton
class NotificationApi({required final AuthenticatedHttpApiClient _client}) {
  Future<void> registerFid({required RegisterFidRequest request}) async {
    final response = await _client.post(
      Uri.parse("$authBaseUrl/notifications/register-token"),
      fromJson: (_) => true,
      body: request.toJson(),
    );

    _throwIfError(response);
  }

  Future<void> unregisterFid({required String fid}) async {
    final encodedFid = Uri.encodeComponent(fid);
    final response = await _client.delete(
      Uri.parse("$authBaseUrl/notifications/fids/$encodedFid"),
      fromJson: (_) => true,
    );

    _throwIfError(response);
  }

  void _throwIfError<T>(ApiResponse<T> response) {
    if (response case ErrorResponse<T>(:final error)) {
      throw error;
    }
  }
}
