import "package:acp_plugin/acp_plugin.dart";

import "models/antigravity_interaction.dart";
import "services/antigravity_interaction_service.dart";

/// Pending lifecycle and attribution delegation; no raw permission policy.
class AntigravityApprovalRegistry({
  required final AntigravityInteractionService _interactionService,
  required super.emit,
  required super.idGenerator,
}) extends AcpPendingRegistry<AntigravityInteraction> {
  this
    : super(
        logContext: "[antigravity]",
        resolvePermission: _interactionService.replyPermission,
        resolveQuestion: _interactionService.replyQuestion,
        rejectQuestion: _interactionService.rejectQuestion,
        cancelPending: _interactionService.cancel,
      );

  @override
  void rejectAmbiguousServerRequest({required AcpServerRequest request}) =>
      _interactionService.rejectAmbiguousServerRequest(request: request);

  @override
  void handleRequest(AcpServerRequest request) {
    switch (_interactionService.classify(request: request)) {
      case final AntigravityPermission permission:
        registerPendingPermission(
          payload: permission,
          sessionId: permission.sessionId,
          displaySessionId: permission.sessionId,
          tool: permission.tool,
          description: permission.description,
          allowAlways: false,
        );
      case final AntigravityQuestion question:
        registerPendingQuestion(
          payload: question,
          sessionId: question.sessionId,
          displaySessionId: question.sessionId,
          questions: [question.question],
        );
      case null:
        break;
    }
  }
}
