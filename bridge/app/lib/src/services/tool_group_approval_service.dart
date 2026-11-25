import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginOperationException;
import "package:sesori_shared/sesori_shared.dart" show PermissionReply;
import "package:sesori_tool_interface/sesori_tool_interface.dart"
    show
        SesoriToolApproval,
        SesoriToolApprovalOutcome,
        SesoriToolApprovalSettled,
        SesoriToolApprovalShown,
        SesoriToolGroupId;

import "../repositories/agent_approval_repository.dart";
import "../repositories/models/agent_approval_change.dart";
import "../repositories/models/session_operation.dart";
import "../repositories/session_repository.dart";
import "permission_auto_approval_service.dart";

/// The Allow requests Sesori tool groups make for their agents, shown as
/// agent approvals beside the tasks' and wake-ups'. Each request waits here
/// until the user answers it, or the bridge begins to stop.
///
/// Approve everything answers for the user: when it covers both the asking
/// session and the root session the request would show on, the change is
/// allowed with no card.
class ToolGroupApprovalService({
  required final AgentApprovalRepository _approvals,
  required final SessionRepository _sessions,
  required final PermissionAutoApprovalService _autoApproval,
}) {
  /// The open requests by request id. In memory only, as every agent approval.
  final Map<String, Completer<SesoriToolApprovalOutcome>> _waiting = {};
  bool _closed = false;

  /// Asks the user to allow [groupId]'s change for [sessionId]'s agent.
  Future<SesoriToolApproval> request({
    required SesoriToolGroupId groupId,
    required String sessionId,
    required String title,
    required String body,
  }) async {
    if (_closed) return const SesoriToolApprovalSettled(outcome: SesoriToolApprovalOutcome.dropped);
    final String rootSessionId;
    try {
      rootSessionId = (await _sessions.resolveSessionFamily(
        sessionId: sessionId,
        operation: SessionOperation.requestToolApproval,
      )).rootSessionId;
    } on PluginOperationException catch (error, stackTrace) {
      Log.w("Dropped a ${groupId.value} approval for session $sessionId", error, stackTrace);
      return const SesoriToolApprovalSettled(outcome: SesoriToolApprovalOutcome.dropped);
    }
    if (await _autoApproval.isYolo(sessionId: sessionId) && await _autoApproval.isYolo(sessionId: rootSessionId)) {
      return const SesoriToolApprovalSettled(outcome: SesoriToolApprovalOutcome.allowed);
    }
    // The bridge may have begun to stop during the reads.
    if (_closed) return const SesoriToolApprovalSettled(outcome: SesoriToolApprovalOutcome.dropped);
    final completer = Completer<SesoriToolApprovalOutcome>();
    final requestId = _approvals.add(
      sessionId: sessionId,
      // A sub-agent's request shows on its root session, like plugin permissions.
      displaySessionId: rootSessionId == sessionId ? null : rootSessionId,
      change: ToolGroupAgentChange(title: title),
      description: body,
    );
    _waiting[requestId] = completer;
    Log.i("Session $sessionId asked for a ${groupId.value} approval ($requestId)");
    return SesoriToolApprovalShown(answer: completer.future);
  }

  /// Hands the user's [reply] to the group waiting on [requestId].
  void settle({required String requestId, required PermissionReply reply}) {
    _waiting
        .remove(requestId)
        ?.complete(
          reply == PermissionReply.reject ? SesoriToolApprovalOutcome.rejected : SesoriToolApprovalOutcome.allowed,
        );
  }

  /// Ends every open request unanswered, and answers later ones the same
  /// way, so nothing waiting on an approval holds up the bridge's stop.
  void dispose() {
    _closed = true;
    final waiting = [..._waiting.values];
    _waiting.clear();
    for (final completer in waiting) {
      completer.complete(SesoriToolApprovalOutcome.dropped);
    }
  }
}
