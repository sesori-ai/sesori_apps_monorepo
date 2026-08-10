import "package:sesori_shared/sesori_shared.dart";

import "../../services/yolo_settings_service.dart";
import "../repositories/permission_repository.dart";
import "request_handler.dart";

/// Handles `POST /session/permissions` — returns the pending permission
/// requests to surface on a session's screen: its own plus any descendant
/// (sub-agent) session whose top-most root resolves to this session.
class GetSessionPermissionsHandler extends BodyRequestHandler<SessionIdRequest, PendingPermissionResponse> {
  final PermissionRepository _permissionRepository;
  final YoloSettingsService _yoloSettingsService;

  GetSessionPermissionsHandler({
    required PermissionRepository permissionRepository,
    required YoloSettingsService yoloSettingsService,
  }) : _permissionRepository = permissionRepository,
       _yoloSettingsService = yoloSettingsService,
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

    final permissions = await _permissionRepository.getPendingPermissions(sessionId: sessionId);

    // Query first to preserve binding/plugin errors; YOLO suppresses only the snapshot response payload.
    if (_yoloSettingsService.currentSettings.enabled) {
      return const PendingPermissionResponse(data: []);
    }

    return PendingPermissionResponse(data: permissions);
  }
}
