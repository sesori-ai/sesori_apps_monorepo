import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/permission_api.dart";
import "../logging/logging.dart";

@lazySingleton
class PermissionRepository({required final PermissionApi _api}) {
  /// Succeeds once the request is no longer pending. A 409 means the bridge
  /// settled it without applying the reply, as for an agent's task request
  /// whose task changed since; the bridge reports that outcome in the session.
  /// A 404 means the harness no longer has it, for example because another
  /// surface answered it first. A retry would fail the same way, so neither
  /// is a failure.
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
    if (response case ErrorResponse(
      error: NonSuccessCodeError(errorCode: final errorCode && (404 || 409), :final rawErrorString),
    )) {
      logi("Permission $requestId is no longer pending ($errorCode): $rawErrorString");
      return ApiResponse.success(null);
    }
    return response;
  }
}
