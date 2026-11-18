import "package:sesori_shared/sesori_shared.dart";

/// How the user's answer to an agent's task request ended.
sealed class const AgentApprovalOutcome();

/// Allowed and applied to an existing task.
final class const AgentApprovalApplied() extends AgentApprovalOutcome;

/// Allowed, and the new task was saved as [taskId].
final class const AgentApprovalCreated({required final String taskId}) extends AgentApprovalOutcome;

final class const AgentApprovalRejected() extends AgentApprovalOutcome;

/// Allowed, but the task was deleted, or what the request was described
/// against changed since, so nothing was applied.
final class const AgentApprovalStale() extends AgentApprovalOutcome;

/// Allowed, but the run did not start; [outcome] says why.
final class const AgentApprovalRunNotStarted({required final ScheduledTaskRunOutcome outcome})
    extends AgentApprovalOutcome;
