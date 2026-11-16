import "package:sesori_shared/sesori_shared.dart";

sealed class const ScheduledTaskDetailState();

final class const ScheduledTaskDetailLoading() extends ScheduledTaskDetailState;

final class const ScheduledTaskDetailLoaded({
  required final ScheduledTask task,

  /// The run history, newest first.
  required final List<ScheduledTaskRun> runs,

  /// Whether this app can send the task's definition back, which renaming
  /// needs. False for a task with parts from a newer peer.
  required final bool editable,
}) extends ScheduledTaskDetailState;

/// The task left the computer's list: it was deleted, or a one-off task ran.
final class const ScheduledTaskDetailGone() extends ScheduledTaskDetailState;

final class const ScheduledTaskDetailFailed() extends ScheduledTaskDetailState;

/// The computer's bridge predates scheduled tasks.
final class const ScheduledTaskDetailBridgeOutdated() extends ScheduledTaskDetailState;
