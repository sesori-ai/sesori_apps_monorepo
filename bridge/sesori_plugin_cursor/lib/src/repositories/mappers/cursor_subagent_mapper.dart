import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../api/models/cursor_subagent_update_dto.dart";
import "../../api/models/cursor_task_dto.dart";

/// How a Cursor child's terminal state settles its tile.
typedef CursorSubagentFinish = ({PluginToolStatus status, String? error});

/// Pure projection of Cursor's native sub-agent lifecycle into the shared
/// child-session vocabulary.
class const CursorSubagentMapper() {
  /// [taskInput] is the parent Task call's input, which carries the prompt the
  /// spawn notification does not repeat. Every child is foreground: Cursor
  /// holds the root prompt open while any child runs, and a root cancel stops
  /// background children too.
  AcpChildSpawn mapSpawned({
    required CursorSubagentSpawnedDto update,
    required CursorTaskInputDto? taskInput,
  }) {
    final task = _nonBlank(value: update.task);
    return AcpChildSpawn(
      childSessionId: update.subagentSessionId,
      description: task ?? _nonBlank(value: taskInput?.description),
      agent: _nonBlank(value: update.name),
      prompt: _nonBlank(value: taskInput?.prompt) ?? task,
      isBackground: false,
    );
  }

  /// Null for a state this build does not know, which must not finish the
  /// child.
  CursorSubagentFinish? mapState({required CursorSubagentState state}) => switch (state) {
    CursorSubagentState.completed => (status: PluginToolStatus.completed, error: null),
    CursorSubagentState.failed => (status: PluginToolStatus.error, error: "Cursor sub-agent failed"),
    CursorSubagentState.cancelled => (status: PluginToolStatus.cancelled, error: null),
    // Never success or a confirmed cancel: the outcome is unknown.
    CursorSubagentState.disconnected => (
      status: PluginToolStatus.error,
      error: "Cursor lost the sub-agent before it reported an outcome",
    ),
    CursorSubagentState.unknown => null,
  };

  String? _nonBlank({required String? value}) => value == null || value.trim().isEmpty ? null : value;
}
