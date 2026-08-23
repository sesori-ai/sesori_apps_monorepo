import "package:sesori_shared/sesori_shared.dart";

import "../services/pending_interaction_service.dart";
import "request_handler.dart";

/// Handles `POST /permission/reply` — replies to a pending permission request.
///
/// The [reply] field accepts "once", "always", or "reject".
class ReplyToPermissionHandler({required final PendingInteractionService _pendingInteractionService})
    extends BodyRequestHandler<ReplyToPermissionRequest, SuccessEmptyResponse> {
  this
    : super(
        HttpMethod.post,
        "/permission/reply",
        fromJson: ReplyToPermissionRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle(
    RelayRequest request, {
    required ReplyToPermissionRequest body,
  }) async {
    final requestId = body.requestId;
    requireNonEmpty(request: request, value: requestId, label: "request id");
    final sessionId = body.sessionId;
    requireNonEmpty(request: request, value: sessionId, label: "session id");

    await _pendingInteractionService.replyToPermission(
      requestId: requestId,
      sessionId: sessionId,
      reply: body.reply,
    );

    return const SuccessEmptyResponse();
  }
}
