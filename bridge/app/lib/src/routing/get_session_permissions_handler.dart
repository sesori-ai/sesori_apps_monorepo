import "package:sesori_shared/sesori_shared.dart";

import "../repositories/permission_repository.dart";
import "../services/permission_auto_approval_service.dart";
import "request_handler.dart";

/// Handles `POST /session/permissions` — returns the pending permission
/// requests to surface on a session's screen: its own plus any descendant
/// (sub-agent) session whose top-most root resolves to this session.
///
/// Under YOLO the snapshot is resolved through auto-approval first: approved
/// requests disappear from the response, while any request YOLO could not
/// answer stays visible so it can be answered manually.
class GetSessionPermissionsHandler({
  required final PermissionRepository _permissionRepository,
  required final PermissionAutoApprovalService _permissionAutoApprovalService,
}) extends BodyRequestHandler<SessionIdRequest, PendingPermissionResponse> {
  this
    : super(
        HttpMethod.post,
        "/session/permissions",
        fromJson: SessionIdRequest.fromJson,
      );

  @override
  Future<PendingPermissionResponse> handle(
    RelayRequest request, {
    required SessionIdRequest body,
  }) async {
    final sessionId = body.sessionId;
    requireNonEmpty(request, sessionId, "session id");

    final permissions = await _permissionRepository.getPendingPermissions(sessionId: sessionId);
    return PendingPermissionResponse(
      data: await _permissionAutoApprovalService.resolveSnapshot(permissions: permissions),
    );
  }
}
