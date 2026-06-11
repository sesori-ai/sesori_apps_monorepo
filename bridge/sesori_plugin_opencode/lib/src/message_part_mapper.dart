import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "models/openapi/part.g.dart";
import "models/openapi/tool_part.g.dart";
import "models/openapi/tool_state.g.dart";
import "models/openapi/tool_state_completed.g.dart";
import "models/openapi/tool_state_error.g.dart";
import "models/openapi/tool_state_pending.g.dart";
import "models/openapi/tool_state_running.g.dart";

class MessagePartMapper {
  const MessagePartMapper();

  PluginMessagePart mapPart(Part raw) {
    final json = raw.toJson();
    final map = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    final rawType = map["type"] as String? ?? "unknown";

    return PluginMessagePart(
      id: map["id"] as String? ?? "",
      sessionID: map["sessionID"] as String? ?? "",
      messageID: map["messageID"] as String? ?? "",
      type: toPluginPartType(type: rawType),
      text: map["text"] as String?,
      tool: map["tool"] as String?,
      state: raw is ToolPart ? _mapToolState(raw.state) : null,
      prompt: map["prompt"] as String?,
      description: map["description"] as String?,
      agent: map["agent"] as String?,
      agentName: map["name"] as String?,
      attempt: (map["attempt"] as num?)?.toInt(),
      retryError: _retryError(map["error"]),
    );
  }

  static PluginMessagePartType toPluginPartType({required String type}) => switch (type) {
    "text" => PluginMessagePartType.text,
    "reasoning" => PluginMessagePartType.reasoning,
    "tool" => PluginMessagePartType.tool,
    "subtask" => PluginMessagePartType.subtask,
    "step-start" => PluginMessagePartType.stepStart,
    "step-finish" => PluginMessagePartType.stepFinish,
    "file" => PluginMessagePartType.file,
    "snapshot" => PluginMessagePartType.snapshot,
    "patch" => PluginMessagePartType.patch,
    "agent" => PluginMessagePartType.agent,
    "retry" => PluginMessagePartType.retry,
    "compaction" => PluginMessagePartType.compaction,
    _ => () {
      Log.w("Unknown message part type: '$type' — filtering out");
      return PluginMessagePartType.unknown;
    }(),
  };

  PluginToolState? _mapToolState(ToolState state) {
    final status = switch (state) {
      ToolStatePending() => "pending",
      ToolStateRunning() => "running",
      ToolStateCompleted() => "completed",
      ToolStateError() => "error",
      ToolStateUnknown(:final raw) => raw is Map<String, dynamic> ? raw["status"]?.toString() : null,
      _ => null,
    };
    final title = switch (state) {
      ToolStateRunning(:final title) => title,
      ToolStateCompleted(:final title) => title,
      _ => null,
    };
    final output = switch (state) {
      ToolStateCompleted(:final output) => output,
      _ => null,
    };
    final error = switch (state) {
      ToolStateError(:final error) => error,
      _ => null,
    };
    return PluginToolState(
      status: status ?? "unknown",
      title: title,
      output: output != null && output.length > maxToolOutputLength
          ? String.fromCharCodes(output.runes.take(maxToolOutputLength))
          : output,
      error: error,
    );
  }

  String? _retryError(Object? error) {
    if (error is Map<String, dynamic>) {
      final data = error["data"];
      if (data is Map<String, dynamic>) return data["message"]?.toString();
      return error["message"]?.toString();
    }
    return null;
  }
}
