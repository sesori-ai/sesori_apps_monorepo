import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../api/models/cursor_task_dto.dart";
import "../mappers/cursor_task_mapper.dart";

/// Replay-local Task facts around one configured ACP collector; owns no transport, process, file, or live state.
final class CursorTaskReplayTracker({
  required final String sessionId,
  required final AcpReplayCollector standardCollector,
  required final CursorTaskMapper taskMapper,
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
    } on Object catch (error, stackTrace) {
      Log.w("[cursor] malformed replay update envelope ignored", error, stackTrace);
      return;
    }
    final toolCallId = envelope.toolCallId;
    if (toolCallId == null || toolCallId.isEmpty) return;
    switch (envelope.sessionUpdate) {
      case CursorTaskReplayUpdateKind.toolCall:
        final inputJson = _asMap(updateJson["rawInput"]);
        if (inputJson == null) return;
        final CursorTaskInputDto identity;
        try {
          identity = CursorTaskInputDto.fromJson({"_toolName": inputJson["_toolName"]});
        } on Object catch (error, stackTrace) {
          Log.w("[cursor] malformed replay tool identity ignored", error, stackTrace);
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
      if (task == null || task.status != CursorTaskReplayStatus.completed || task.mode != _Mode.foreground) return null;
      final input = task.input;
      final prompt = input.prompt;
      final description = input.description;
      final subagentType = input.subagentType;
      if (prompt == null || description == null || subagentType == null) return null;
      return taskMapper.completedForeground(
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
    if (update.status == CursorTaskReplayStatus.completed) task.status = CursorTaskReplayStatus.completed;
    final rawOutput = updateJson["rawOutput"];
    if (rawOutput == null) return;
    final outputJson = _asMap(rawOutput);
    if (outputJson == null) {
      _logMalformedTaskFact();
      return;
    }
    try {
      final output = CursorTaskOutputDto.fromJson({"isBackground": outputJson["isBackground"]});
      task.mode = output.isBackground ? _Mode.background : _Mode.foreground;
    } on Object catch (error, stackTrace) {
      Log.w("[cursor] malformed replay Task output ignored", error, stackTrace);
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

  // A complete Task fact may contain transcript text. Do not attach parser errors.
  static void _logMalformedTaskFact() => Log.w("[cursor] malformed replay Task fact ignored");

  static Map<String, dynamic>? _asMap(Object? value) => value is Map ? value.cast<String, dynamic>() : null;
}

enum _Mode() {
  unknown,
  foreground,
  background,
}

final class _CursorReplayTask({required final CursorTaskReplayInputDto input}) {
  CursorTaskReplayStatus status = CursorTaskReplayStatus.pending;
  _Mode mode = _Mode.unknown;
}
