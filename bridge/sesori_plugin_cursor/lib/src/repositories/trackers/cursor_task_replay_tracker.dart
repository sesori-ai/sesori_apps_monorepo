import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../api/models/cursor_task_dto.dart";
import "../mappers/cursor_task_projection.dart";

/// Replay-local Cursor Task fact index around one fully configured standard ACP
/// collector. It owns no transport, process, file, live-tracker, or event state.
final class CursorTaskReplayTracker({
  required final String sessionId,
  required final AcpReplayCollector standardCollector,
  required final CursorTaskProjection taskProjection,
}) implements AcpSessionReplayCollector {
  final Map<String, _CursorReplayTask> _tasksByToolCallId = {};

  @override
  void consumeNotification({required AcpNotification notification}) {
    standardCollector.consumeNotification(notification: notification);
    if (notification.method != AcpMethods.sessionUpdate) return;

    if (notification.params["sessionId"] != sessionId) return;
    final updateJson = _asMap(notification.params["update"]);
    if (updateJson == null) return;
    final CursorTaskReplayUpdateDto envelope;
    try {
      envelope = CursorTaskReplayUpdateDto.fromJson({
        "sessionUpdate": updateJson["sessionUpdate"],
        "toolCallId": updateJson["toolCallId"],
      });
    } on Object {
      return;
    }

    final toolCallId = _nonblank(envelope.toolCallId);
    if (toolCallId == null) return;
    switch (envelope.sessionUpdate) {
      case CursorTaskReplayUpdateKind.toolCall:
        final inputJson = _asMap(updateJson["rawInput"]);
        if (inputJson == null) return;
        final CursorTaskInputDto identity;
        try {
          identity = CursorTaskInputDto.fromJson(inputJson);
        } on Object {
          return;
        }
        if (identity.toolName != CursorTaskTool.task) return;
        final CursorTaskReplayInputDto input;
        try {
          input = CursorTaskReplayInputDto.fromJson(inputJson);
        } on Object {
          _logMalformedTaskFact();
          return;
        }
        final update = _parseTaskUpdate(updateJson);
        if (update == null) return;
        final task = _CursorReplayTask(input: input);
        _tasksByToolCallId[toolCallId] = task;
        _mergeTerminalOutput(task: task, update: update, updateJson: updateJson);
      case CursorTaskReplayUpdateKind.toolCallUpdate:
        final task = _tasksByToolCallId[toolCallId];
        if (task == null) return;
        final update = _parseTaskUpdate(updateJson);
        if (update != null) _mergeTerminalOutput(task: task, update: update, updateJson: updateJson);
      case CursorTaskReplayUpdateKind.unknown:
        break;
    }
  }

  @override
  List<PluginMessageWithParts> buildWithAssistantSelection({
    required String? modelId,
    required String? providerId,
    required String? variant,
  }) => standardCollector.buildWithToolPartReplacement(
    modelId: modelId,
    providerId: providerId,
    variant: variant,
    toolPartReplacement: ({required toolCallId, required toolPart}) {
      final task = _tasksByToolCallId[toolCallId];
      if (task == null || !task.hasCompleted || (task.isBackground ?? true)) return null;
      final input = task.input;
      final prompt = input.prompt;
      final description = input.description;
      final subagentType = input.subagentType;
      if (prompt == null || description == null || subagentType == null) return null;
      return taskProjection.completedForeground(
        genericPart: toolPart,
        prompt: prompt,
        description: description,
        subagentType: subagentType,
      );
    },
  );

  void _mergeTerminalOutput({
    required _CursorReplayTask task,
    required CursorTaskReplayUpdateDto update,
    required Map<String, dynamic> updateJson,
  }) {
    if (update.status == CursorTaskReplayStatus.completed) task.hasCompleted = true;
    final rawOutput = updateJson["rawOutput"];
    if (rawOutput == null) return;
    final outputJson = _asMap(rawOutput);
    if (outputJson == null) {
      _logMalformedTaskFact();
      return;
    }
    try {
      task.isBackground = CursorTaskOutputDto.fromJson(outputJson).isBackground;
    } on Object {
      _logMalformedTaskFact();
    }
  }

  static CursorTaskReplayUpdateDto? _parseTaskUpdate(Map<String, dynamic> updateJson) {
    try {
      return CursorTaskReplayUpdateDto.fromJson(updateJson);
    } on Object {
      _logMalformedTaskFact();
      return null;
    }
  }

  static void _logMalformedTaskFact() {
    // Task input may contain transcript text. Do not attach parser errors.
    Log.w("[cursor] malformed replay Task fact ignored");
  }

  static Map<String, dynamic>? _asMap(Object? value) => value is Map ? value.cast<String, dynamic>() : null;

  static String? _nonblank(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

final class _CursorReplayTask({required final CursorTaskReplayInputDto input}) {
  bool hasCompleted = false;
  bool? isBackground;
}
