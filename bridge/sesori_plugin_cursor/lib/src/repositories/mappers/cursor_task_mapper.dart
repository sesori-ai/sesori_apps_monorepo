import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../api/models/cursor_task_dto.dart";

enum CursorSubagentPresentation() {
  unspecified,
  unknown,
}

/// Pure Cursor Task transport normalization and completed presentation shared
/// by live mapping and replay-local history projection.
final class const CursorTaskMapper() {
  CursorSubagentPresentation livePresentation({required CursorSubagentTypeDto subagentType}) =>
      subagentType.custom?.unspecified == null
      ? CursorSubagentPresentation.unknown
      : CursorSubagentPresentation.unspecified;

  CursorSubagentPresentation replayPresentation({required CursorTaskReplaySubagentTypeDto subagentType}) =>
      subagentType.unspecified == null ? CursorSubagentPresentation.unknown : CursorSubagentPresentation.unspecified;

  PluginMessagePart? completedForeground({
    required PluginMessagePartTool genericPart,
    required String prompt,
    required String description,
    required CursorSubagentPresentation subagentPresentation,
  }) {
    if (genericPart.state.status != PluginToolStatus.completed) return null;
    final usefulPrompt = _nonblank(prompt);
    final usefulDescription = _nonblank(description);
    final agent = switch (subagentPresentation) {
      CursorSubagentPresentation.unspecified => CursorSubagentPresentation.unspecified.name,
      CursorSubagentPresentation.unknown => null,
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
