import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../api/permission_api.dart";

@lazySingleton
class PermissionRepository {
  final PermissionApi _api;

  PermissionRepository({required PermissionApi api}) : _api = api;

  Future<ApiResponse<void>> replyToPermission({
    required String requestId,
    required String sessionId,
    required String response,
  }) {
    return _api.replyToPermission(
      requestId: requestId,
      sessionId: sessionId,
      response: response,
    );
  }
}
