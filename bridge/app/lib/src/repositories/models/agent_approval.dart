import "package:sesori_shared/sesori_shared.dart" show PendingPermission, PermissionReply;

import "scheduled_task_agent_change.dart";

/// A change an agent proposed, shown to the user as a permission request on
/// the session that asked. It lives in memory only, so a bridge restart drops
/// it and the next run can propose again.
final class const AgentApproval({
  required final String requestId,
  required final String sessionId,

  /// The root session the request is surfaced under, or null when
  /// [sessionId] is a root.
  required final String? displaySessionId,
  required final ScheduledTaskAgentChange change,

  /// The Markdown the user approves.
  required final String description,
});

sealed class const AgentApprovalEvent();

final class const AgentApprovalAsked({required final PendingPermission permission}) extends AgentApprovalEvent;

/// Answered by the user, or withdrawn by a newer proposal from the same
/// session ([reply] is then [PermissionReply.reject]).
final class const AgentApprovalSettled({
  required final String requestId,
  required final String sessionId,
  required final String? displaySessionId,
  required final PermissionReply reply,
}) extends AgentApprovalEvent;
