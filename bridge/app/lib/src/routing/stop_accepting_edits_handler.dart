import "package:sesori_shared/sesori_shared.dart";

import "../repositories/permission_repository.dart";
import "request_handler.dart";

/// Handles `POST /session/stop-accepting-edits` — ends the session's "edits
/// run without asking" grant, so its next file edit asks again.
class StopAcceptingEditsHandler({required final PermissionRepository _permissionRepository})
    extends BodyRequestHandler<SessionIdRequest, SuccessEmptyResponse> {
  this
    : super(
        method: HttpMethod.post,
        path: "/session/stop-accepting-edits",
        fromJson: SessionIdRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle({
    required RelayRequest request,
    required SessionIdRequest body,
  }) async {
    final sessionId = body.sessionId;
    requireNonEmpty(request: request, value: sessionId, label: "session id");
    await _permissionRepository.stopAcceptingEdits(sessionId: sessionId);
    return const SuccessEmptyResponse();
  }
}
