/// Terminal status of a Claude Code background task, as reported by the
/// `system/task_notification` frame and the `<task-notification>` user text.
enum ClaudeTaskStatus() {
  completed,
  failed,
  stopped,
  unknown;

  static ClaudeTaskStatus parse(Object? raw) => switch (raw) {
    "completed" => completed,
    "failed" => failed,
    "stopped" => stopped,
    _ => unknown,
  };
}
