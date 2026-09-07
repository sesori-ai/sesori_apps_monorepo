import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "models/antigravity_interaction.dart";
import "services/antigravity_interaction_service.dart";

/// Pending lifecycle only. Shared ACP registry integration is composed in Step 8.
class AntigravityApprovalRegistry({
  required final AntigravityInteractionService _interactionService,
  required super.emit,
  required super.idGenerator,
}) extends PendingPermissionRegistry<AcpServerRequest, AntigravityInteraction> {
  this
    : super(
        logContext: "[antigravity]",
        resolvePermission: _interactionService.replyPermission,
        resolveQuestion: _interactionService.replyQuestion,
        rejectQuestion: _interactionService.rejectQuestion,
        cancelPending: _interactionService.cancel,
      );

  void handleServerRequest({required AcpServerRequest request}) => handleRequest(request);

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
