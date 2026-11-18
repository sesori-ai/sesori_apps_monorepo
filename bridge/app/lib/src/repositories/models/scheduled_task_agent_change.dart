import "package:sesori_shared/sesori_shared.dart" show ScheduledTaskDefinition;

/// A change to a stored task that an agent proposed, waiting for the user's
/// Allow. [before] is the definition the request's description was built
/// from; Allow applies the change only while the stored definition still
/// equals it, so the user never approves a task whose current state they were
/// not shown.
sealed class const ScheduledTaskAgentChange({
  required final String taskId,
  required final ScheduledTaskDefinition before,
});

final class const SetTaskEnabledChange({required super.taskId, required super.before, required final bool enabled})
    extends ScheduledTaskAgentChange;

final class const RunTaskNowChange({required super.taskId, required super.before}) extends ScheduledTaskAgentChange;
