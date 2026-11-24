/// What a task update does to the shell command the task runs before each
/// run's prompt.
sealed class const TaskCommandEdit();

/// Keeps the command, or its absence.
final class const TaskCommandUnchanged() extends TaskCommandEdit;

final class const TaskCommandSet({required final String command}) extends TaskCommandEdit;

final class const TaskCommandRemoved() extends TaskCommandEdit;
