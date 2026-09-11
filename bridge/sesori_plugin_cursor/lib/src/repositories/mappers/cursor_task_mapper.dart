import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../api/models/cursor_task_dto.dart";

/// Pure completed-foreground Cursor Task presentation shared by live mapping
/// and replay-local history projection.
final class const CursorTaskMapper() {
  PluginMessagePart? completedForeground({
    required PluginMessagePartTool genericPart,
    required String prompt,
    required String description,
    required CursorSubagentTypeDto subagentType,
  }) {
    if (genericPart.state.status != PluginToolStatus.completed) return null;
    final usefulPrompt = _nonblank(prompt);
    final usefulDescription = _nonblank(description);
    final agent = switch (subagentType.custom) {
      CursorSubagentType.unspecified => CursorSubagentType.unspecified.name,
      CursorSubagentType.unknown || null => null,
    };
    if (usefulPrompt == null || usefulDescription == null || agent == null) return null;

    return PluginMessagePart.subtask(
      id: genericPart.id,
      sessionID: genericPart.sessionID,
      messageID: genericPart.messageID,
      prompt: usefulPrompt,
      description: usefulDescription,
      agent: agent,
      taskState: PluginToolState(
        status: PluginToolStatus.completed,
        title: genericPart.state.title,
        shellCommand: null,
        output: genericPart.state.output,
        error: null,
        attachments: genericPart.state.attachments,
      ),
      childSessionID: null,
    );
  }

  static String? _nonblank(String value) => value.trim().isEmpty ? null : value;
}
