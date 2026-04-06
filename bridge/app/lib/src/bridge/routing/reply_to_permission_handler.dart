import "package:sesori_shared/sesori_shared.dart";

import "../repositories/permission_repository.dart";
import "request_handler.dart";

/// Handles `POST /permission/reply` — replies to a pending permission request.
///
/// The [reply] field accepts "once", "always", or "reject".
class ReplyToPermissionHandler extends BodyRequestHandler<ReplyToPermissionRequest, SuccessEmptyResponse> {
  final PermissionRepository _permissionRepository;

  ReplyToPermissionHandler({required PermissionRepository permissionRepository})
    : _permissionRepository = permissionRepository,
      super(
        HttpMethod.post,
        "/permission/reply",
        fromJson: ReplyToPermissionRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle(
    RelayRequest request, {
    required ReplyToPermissionRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    final requestId = body.requestId;
    if (requestId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty request id");
    }
    final sessionId = body.sessionId;
    if (sessionId.isEmpty) {
      throw buildErrorResponse(request, 400, "empty session id");
    }

    await _permissionRepository.replyToPermission(
      requestId: requestId,
      sessionId: sessionId,
      reply: body.reply,
    );

    return const SuccessEmptyResponse();
  }
}
