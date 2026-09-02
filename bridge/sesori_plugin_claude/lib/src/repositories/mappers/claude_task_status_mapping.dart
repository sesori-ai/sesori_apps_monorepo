import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../models/claude_task_status.dart";

/// The one place a task's terminal status becomes a subtask part status, for
/// live frames and transcript replay alike.
extension ClaudeTaskStatusMapping on ClaudeTaskStatus {
  PluginToolStatus toPluginToolStatus() => switch (this) {
    ClaudeTaskStatus.completed => PluginToolStatus.completed,
    ClaudeTaskStatus.failed => PluginToolStatus.error,
    ClaudeTaskStatus.stopped => PluginToolStatus.cancelled,
    ClaudeTaskStatus.unknown => PluginToolStatus.unknown,
  };
}
