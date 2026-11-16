import "package:sesori_shared/sesori_shared.dart" show TaskRunFailureReason;

/// A task run that could not start, for the can't-start push.
final class const ScheduledTaskRunFailure({
  required final String taskId,
  required final String taskName,
  required final TaskRunFailureReason reason,
});
