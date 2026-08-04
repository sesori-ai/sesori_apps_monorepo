import "package:sesori_shared/sesori_shared.dart";

import "../repositories/permission_repository.dart";
import "request_handler.dart";

/// Handles `POST /session/permissions` — returns the pending permission
/// requests to surface on a session's screen: its own plus any descendant
/// (sub-agent) session whose top-most root resolves to this session.
class GetSessionPermissionsHandler extends BodyRequestHandler<SessionIdRequest, PendingPermissionResponse> {
  final PermissionRepository _permissionRepository;
  final bool _suppressPendingPermissions;

  GetSessionPermissionsHandler({
    required PermissionRepository permissionRepository,
    required bool suppressPendingPermissions,
  }) : _permissionRepository = permissionRepository,
       _suppressPendingPermissions = suppressPendingPermissions,
       super(
         HttpMethod.post,
         "/session/permissions",
         fromJson: SessionIdRequest.fromJson,
       );

  @override
  Future<PendingPermissionResponse> handle(
    RelayRequest request, {
    required SessionIdRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final sessionId = body.sessionId;
    if (sessionId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty session id");
    }

    // YOLO suppresses permission prompts from both live events and this snapshot path.
    if (_suppressPendingPermissions) {
      return const PendingPermissionResponse(data: []);
    }

    final permissions = await _permissionRepository.getPendingPermissions(sessionId: sessionId);
    return PendingPermissionResponse(data: permissions);
  }
}
