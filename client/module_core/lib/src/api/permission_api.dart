import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "client/relay_http_client.dart";

@lazySingleton
class PermissionApi({required RelayHttpApiClient client}) {
  final RelayHttpApiClient _client;

  this : _client = client;

  Future<ApiResponse<void>> replyToPermission({
    required String requestId,
    required String sessionId,
    required PermissionReply reply,
  }) {
    return _client.post(
      "/permission/reply",
      fromJson: SuccessEmptyResponse.fromJson,
      body: ReplyToPermissionRequest(requestId: requestId, sessionId: sessionId, reply: reply),
    );
  }
}
