import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "models/openapi/agent_part.g.dart";
import "models/openapi/compaction_part.g.dart";
import "models/openapi/file_part.g.dart";
import "models/openapi/part.g.dart";
import "models/openapi/patch_part.g.dart";
import "models/openapi/reasoning_part.g.dart";
import "models/openapi/retry_part.g.dart";
import "models/openapi/snapshot_part.g.dart";
import "models/openapi/step_finish_part.g.dart";
import "models/openapi/step_start_part.g.dart";
import "models/openapi/subtask_part.g.dart";
import "models/openapi/text_part.g.dart";
import "models/openapi/tool_part.g.dart";
import "models/openapi/tool_state.g.dart";
import "models/openapi/tool_state_completed.g.dart";
import "models/openapi/tool_state_error.g.dart";
import "models/openapi/tool_state_pending.g.dart";
import "models/openapi/tool_state_running.g.dart";

class MessagePartMapper {
  const MessagePartMapper();

  /// Maps a generated [Part] union to the plugin-facing [PluginMessagePart].
  ///
  /// Dispatches on the sealed [Part] variants — the generated discriminator
  /// is exposed as distinct Dart types, so there is no string matching on a
  /// `type` field and the common `id`/`sessionID`/`messageID` are read as
  /// strongly-typed, non-null fields (no `?? ""` fallbacks).
  PluginMessagePart mapPart(Part raw) => switch (raw) {
    TextPart() => _part(raw.id, raw.sessionID, raw.messageID, PluginMessagePartType.text, text: raw.text),
    ReasoningPart() => _part(raw.id, raw.sessionID, raw.messageID, PluginMessagePartType.reasoning, text: raw.text),
    ToolPart() => _part(
      raw.id,
      raw.sessionID,
      raw.messageID,
      PluginMessagePartType.tool,
      tool: raw.tool,
      state: _mapToolState(raw.state),
    ),
    SubtaskPart() => _part(
      raw.id,
      raw.sessionID,
      raw.messageID,
      PluginMessagePartType.subtask,
      prompt: raw.prompt,
      description: raw.description,
      agent: raw.agent,
    ),
    AgentPart() => _part(raw.id, raw.sessionID, raw.messageID, PluginMessagePartType.agent, agentName: raw.name),
    RetryPart() => _part(
      raw.id,
      raw.sessionID,
      raw.messageID,
      PluginMessagePartType.retry,
      attempt: raw.attempt,
      retryError: raw.error.data.message,
    ),
    FilePart() => _part(raw.id, raw.sessionID, raw.messageID, PluginMessagePartType.file),
    SnapshotPart() => _part(raw.id, raw.sessionID, raw.messageID, PluginMessagePartType.snapshot),
    PatchPart() => _part(raw.id, raw.sessionID, raw.messageID, PluginMessagePartType.patch),
    CompactionPart() => _part(
      raw.id,
      raw.sessionID,
      raw.messageID,
      PluginMessagePartType.compaction,
    ),
    StepStartPart() => _part(raw.id, raw.sessionID, raw.messageID, PluginMessagePartType.stepStart),
    StepFinishPart() => _part(raw.id, raw.sessionID, raw.messageID, PluginMessagePartType.stepFinish),
    // `Part` is an `abstract interface` (not `sealed`), so a default arm is
    // required. `PartUnknown` and any future variant fall through here and
    // become an `unknown` part, which downstream mapping filters out.
    _ => _unknownPart(raw),
  };

  PluginMessagePart _part(
    String id,
    String sessionID,
    String messageID,
    PluginMessagePartType type, {
    String? text,
    String? tool,
    PluginToolState? state,
    String? prompt,
    String? description,
    String? agent,
    String? agentName,
    int? attempt,
    String? retryError,
  }) => PluginMessagePart(
    id: id,
    sessionID: sessionID,
    messageID: messageID,
    type: type,
    text: text,
    tool: tool,
    state: state,
    prompt: prompt,
    description: description,
    agent: agent,
    agentName: agentName,
    attempt: attempt,
    retryError: retryError,
  );

  /// An unrecognized part shape. Every OpenCode part carries `id`,
  /// `sessionID` and `messageID` on the base schema, so they are read back
  /// from the round-tripped JSON; a part missing them is malformed and
  /// surfaces loudly via the cast rather than being silently defaulted.
  PluginMessagePart _unknownPart(Part raw) {
    final json = raw.toJson();
    final map = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    return _part(
      map["id"] as String,
      map["sessionID"] as String,
      map["messageID"] as String,
      PluginMessagePartType.unknown,
    );
  }

  PluginToolState _mapToolState(ToolState state) {
    final status = switch (state) {
      ToolStatePending() => PluginToolStatus.pending,
      ToolStateRunning() => PluginToolStatus.running,
      ToolStateCompleted() => PluginToolStatus.completed,
      ToolStateError() => PluginToolStatus.error,
      // `ToolState` is an `abstract interface` (not `sealed`); ToolStateUnknown
      // and any future variant map to `unknown`.
      _ => PluginToolStatus.unknown,
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
      status: status,
      title: title,
      output: output != null && output.length > maxToolOutputLength
          ? String.fromCharCodes(output.runes.take(maxToolOutputLength))
          : output,
      error: error,
    );
  }
}
