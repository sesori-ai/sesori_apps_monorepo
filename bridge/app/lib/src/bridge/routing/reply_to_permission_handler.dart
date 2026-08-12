import "package:sesori_shared/sesori_shared.dart";

import "../services/pending_interaction_service.dart";
import "request_handler.dart";

/// Handles `POST /permission/reply` — replies to a pending permission request.
///
/// The [reply] field accepts "once", "always", or "reject".
class ReplyToPermissionHandler({required PendingInteractionService pendingInteractionService}) extends BodyRequestHandler<ReplyToPermissionRequest, SuccessEmptyResponse> {
  final PendingInteractionService _pendingInteractionService;

  this
    : _pendingInteractionService = pendingInteractionService,
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

    await _pendingInteractionService.replyToPermission(
      requestId: requestId,
      sessionId: sessionId,
      reply: body.reply,
    );

    return const SuccessEmptyResponse();
  }
}
