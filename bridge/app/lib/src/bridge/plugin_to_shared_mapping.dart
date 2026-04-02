import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Maps [PluginMessagePartType] to [MessagePartType] with compile-time safety.
/// An exhaustive switch ensures any new enum value causes a compile error here,
/// rather than a runtime crash.
extension PluginMessagePartTypeMapping on PluginMessagePartType {
  MessagePartType toShared() => switch (this) {
    PluginMessagePartType.text => MessagePartType.text,
    PluginMessagePartType.reasoning => MessagePartType.reasoning,
    PluginMessagePartType.tool => MessagePartType.tool,
    PluginMessagePartType.subtask => MessagePartType.subtask,
    PluginMessagePartType.stepStart => MessagePartType.stepStart,
    PluginMessagePartType.stepFinish => MessagePartType.stepFinish,
    PluginMessagePartType.file => MessagePartType.file,
    PluginMessagePartType.snapshot => MessagePartType.snapshot,
    PluginMessagePartType.patch => MessagePartType.patch,
    PluginMessagePartType.agent => MessagePartType.agent,
    PluginMessagePartType.retry => MessagePartType.retry,
    PluginMessagePartType.compaction => MessagePartType.compaction,
    PluginMessagePartType.unknown => throw StateError(
      "PluginMessagePartType.unknown must be filtered out before mapping to shared model",
    ),
  };
}

/// Maps [PluginToolState] to the shared [ToolState].
extension PluginToolStateMapping on PluginToolState {
  ToolState toShared() => ToolState(
    status: status,
    title: title,
    output: output,
    error: error,
  );
}

extension PluginCommandSourceMapping on PluginCommandSource {
  CommandSource toShared() => switch (this) {
    PluginCommandSource.command => CommandSource.command,
    PluginCommandSource.mcp => CommandSource.mcp,
    PluginCommandSource.skill => CommandSource.skill,
    PluginCommandSource.unknown => CommandSource.unknown,
  };
}

extension PluginCommandMapping on PluginCommand {
  /// Maps to shared [CommandInfo] for the mobile client.
  ///
  /// The `template` field is intentionally excluded: it contains the full
  /// prompt text (often thousands of characters) that the mobile UI never
  /// displays.  Stripping it shrinks a typical response from ~400 KB to ~20 KB,
  /// preventing relay timeouts and WebSocket frame issues.
  CommandInfo toShared() => CommandInfo(
    name: name,
    hints: hints,
    description: description,
    agent: agent,
    model: model,
    provider: provider,
    source: source?.toShared(),
    subtask: subtask,
  );
}

/// Maps [PluginMessagePart] to the shared [MessagePart].
extension PluginMessagePartMapping on PluginMessagePart {
  MessagePart toShared() => MessagePart(
    id: id,
    sessionID: sessionID,
    messageID: messageID,
    type: type.toShared(),
    text: text,
    tool: tool,
    state: state?.toShared(),
    prompt: prompt,
    description: description,
    agent: agent,
    agentName: agentName,
    attempt: attempt,
    retryError: retryError,
  );
}
