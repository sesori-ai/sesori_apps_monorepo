import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/permission_api.dart";

@lazySingleton
class PermissionRepository {
  final PermissionApi _api;

  PermissionRepository({required PermissionApi api}) : _api = api;

  Future<ApiResponse<void>> replyToPermission({
    required String requestId,
    required String sessionId,
    required PermissionReply reply,
  }) {
    return _api.replyToPermission(
      requestId: requestId,
      sessionId: sessionId,
      reply: reply,
    );
  }
}
