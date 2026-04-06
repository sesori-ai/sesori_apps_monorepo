import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "client/relay_http_client.dart";

@lazySingleton
class PermissionApi {
  final RelayHttpApiClient _client;

  PermissionApi({required RelayHttpApiClient client}) : _client = client;

  Future<ApiResponse<void>> replyToPermission({
    required String requestId,
    required String sessionId,
    required String response,
  }) {
    return _client.post(
      "/permission/reply",
      fromJson: SuccessEmptyResponse.fromJson,
      body: ReplyToPermissionRequest(requestId: requestId, sessionId: sessionId, response: response),
    );
  }
}
