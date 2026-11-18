import "package:sesori_shared/sesori_shared.dart" show ScheduledTaskDefinition;

/// A scheduled-task change an agent proposed, waiting for the user's Allow.
sealed class const ScheduledTaskAgentChange();

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
