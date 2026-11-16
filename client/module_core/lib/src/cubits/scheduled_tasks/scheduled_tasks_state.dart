import "package:sesori_shared/sesori_shared.dart";

sealed class const ScheduledTasksState();

final class const ScheduledTasksLoading() extends ScheduledTasksState;

/// The computer's tasks under their headings, either of which may be empty.
final class const ScheduledTasksLoaded({
  /// Recurring tasks in the bridge's order, which a run never changes. A task
  /// whose schedule this app does not know is listed here.
  required final List<ScheduledTask> recurring,

  /// One-off tasks, soonest first.
  required final List<ScheduledTask> once,

  /// This device's IANA zone; null when the platform cannot report it.
  required final String? deviceTimeZone,
}) extends ScheduledTasksState;

final class const ScheduledTasksFailed() extends ScheduledTasksState;

/// The computer's bridge predates scheduled tasks.
final class const ScheduledTasksBridgeOutdated() extends ScheduledTasksState;
