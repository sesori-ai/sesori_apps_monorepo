import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/permission_api.dart";
import "../logging/logging.dart";

@lazySingleton
class PermissionRepository({required final PermissionApi _api}) {
  /// Succeeds once the bridge has taken the answer, a 409 included: the bridge
  /// settled the request but could not apply it as sent, as for an agent's
  /// task request whose task changed since. The bridge reports that outcome in
  /// the session, so the request is answered and needs no retry.
  Future<ApiResponse<void>> replyToPermission({
    required String requestId,
    required String sessionId,
    required PermissionReply reply,
  }) async {
    final response = await _api.replyToPermission(
      requestId: requestId,
      sessionId: sessionId,
      reply: reply,
    );
    if (response case ErrorResponse(error: NonSuccessCodeError(errorCode: 409, :final rawErrorString))) {
      logi("Permission $requestId was answered without applying the reply: $rawErrorString");
      return ApiResponse.success(null);
    }
    return response;
  }
}
