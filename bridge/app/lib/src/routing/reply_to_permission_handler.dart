import "package:sesori_shared/sesori_shared.dart";

import "../services/pending_interaction_service.dart";
import "../services/scheduled_task_agent_service.dart";
import "request_handler.dart";

/// Handles `POST /permission/reply` — replies to a pending permission request.
///
/// The [reply] field accepts "once", "always", or "reject". An agent's task
/// approval is settled by the bridge; every other request goes to its plugin.
class ReplyToPermissionHandler({
  required final ScheduledTaskAgentService _scheduledTaskAgentService,
  required final PendingInteractionService _pendingInteractionService,
}) extends BodyRequestHandler<ReplyToPermissionRequest, SuccessEmptyResponse> {
  this
    : super(
        method: HttpMethod.post,
        path: "/permission/reply",
        fromJson: ReplyToPermissionRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle({
    required RelayRequest request,
    required ReplyToPermissionRequest body,
  }) async {
    final requestId = body.requestId;
    requireNonEmpty(request: request, value: requestId, label: "request id");
    final sessionId = body.sessionId;
    requireNonEmpty(request: request, value: sessionId, label: "session id");

    switch (await _scheduledTaskAgentService.settle(requestId: requestId, reply: body.reply)) {
      case NotAgentApproval():
        await _pendingInteractionService.replyToPermission(
          requestId: requestId,
          sessionId: sessionId,
          reply: body.reply,
        );
      case AgentApprovalStale():
        throw buildErrorResponse(
          request: request,
          status: 409,
          message: "The task changed since this was proposed, so nothing was applied.",
        );
      case AgentApprovalRunNotStarted():
        throw buildErrorResponse(
          request: request,
          status: 409,
          message: "Allowed, but the task could not start. Its run history shows why.",
        );
      case AgentApprovalApplied() || AgentApprovalRejected():
        break;
    }

    return const SuccessEmptyResponse();
  }
}
