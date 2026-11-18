import "package:sesori_shared/sesori_shared.dart" show ScheduledTaskDefinition;

/// A scheduled-task change an agent proposed, waiting for the user's Allow.
sealed class const ScheduledTaskAgentChange();

final class const CreateTaskChange({required final ScheduledTaskDefinition definition})
    extends ScheduledTaskAgentChange;

/// A change to a stored task. [before] is the definition the request's
/// description was built from; Allow applies the change only while the stored
/// definition still equals it, so the user never approves a task whose
/// current state they were not shown.
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
