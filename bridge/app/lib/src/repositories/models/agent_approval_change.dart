import "package:sesori_shared/sesori_shared.dart" show ScheduledTaskDefinition;

import "session_wake_up.dart";

/// A change an agent asked for, waiting for the user's Allow.
sealed class const AgentApprovalChange();

/// A scheduled-task change an agent proposed.
sealed class const ScheduledTaskAgentChange() extends AgentApprovalChange;

final class const CreateTaskChange({required final ScheduledTaskDefinition definition})
    extends ScheduledTaskAgentChange;

/// A change to a stored task. [before] is the definition the request's
/// description was built from. Allow applies the change only while what the
/// description showed still holds: the fields the change sets, the approval
/// mode its Approve everything warning came from (except for a pause), and a
/// resume's schedule. Other fields may change meanwhile, for example through
/// another request of the same session, and an update applies only its own
/// fields on top of them.
sealed class const StoredTaskChange({required final String taskId, required final ScheduledTaskDefinition before})
    extends ScheduledTaskAgentChange;

final class const UpdateTaskChange({
  required super.taskId,
  required super.before,
  required final ScheduledTaskDefinition after,
}) extends StoredTaskChange;

final class const SetTaskEnabledChange({required super.taskId, required super.before, required final bool enabled})
    extends StoredTaskChange;

final class const RunTaskNowChange({required super.taskId, required super.before}) extends StoredTaskChange;

/// A wake-up command waiting for the user's Allow.
sealed class const WakeUpCommandChange() extends AgentApprovalChange;

/// A new wake-up that runs [command], asked for outside Approve everything.
/// Allow stores it, its first time counting from the Allow.
final class const ScheduleCommandWakeUp({
  /// The root session the wake-up is for.
  required final String sessionId,
  required final String label,
  required final String prompt,
  required final String command,
  required final WakeUpRequestedTime when,

  /// The zone the agent named, or null for the bridge computer's.
  required final String? timeZone,
}) extends WakeUpCommandChange;

/// A stored wake-up whose command was set while its session approved
/// everything, firing after the session stopped. Allow runs the command and
/// records the approval; Reject cancels the wake-up.
final class const ConfirmByModeCommand({
  required final StoredSessionWakeUp wakeUp,

  /// [wakeUp]'s command.
  required final String command,

  /// When the occurrence waiting for this answer fired.
  required final DateTime firedAt,
}) extends WakeUpCommandChange;
