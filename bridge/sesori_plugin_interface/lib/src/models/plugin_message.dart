import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_message.freezed.dart";

part "plugin_message.g.dart";

/// Maximum length for tool output sent to mobile.
/// Mobile truncates to this length anyway, so we truncate at the source.
const maxToolOutputLength = 500;

@JsonEnum()
enum PluginMessagePartType {
  @JsonValue("text")
  text,
  @JsonValue("reasoning")
  reasoning,
  @JsonValue("tool")
  tool,
  @JsonValue("subtask")
  subtask,
  @JsonValue("step-start")
  stepStart,
  @JsonValue("step-finish")
  stepFinish,
  @JsonValue("file")
  file,
  @JsonValue("snapshot")
  snapshot,
  @JsonValue("patch")
  patch,
  @JsonValue("agent")
  agent,
  @JsonValue("retry")
  retry,
  @JsonValue("compaction")
  compaction,
  @JsonValue("unknown")
  unknown
  ;

  /// Whether this part type is visible to mobile (rendered in the UI).
  bool get isVisible => this != file && this != snapshot && this != patch && this != compaction && this != unknown;
}

@freezed
sealed class PluginMessageWithParts with _$PluginMessageWithParts {
  const factory PluginMessageWithParts({
    required PluginMessage info,
    required List<PluginMessagePart> parts,
  }) = _PluginMessageWithParts;
}

@freezed
sealed class PluginMessagePart with _$PluginMessagePart {
  const factory PluginMessagePart({
    required String id,
    required String sessionID,
    required String messageID,
    required PluginMessagePartType type,
    // text / reasoning
    required String? text,
    // tool
    required String? tool,
    required PluginToolState? state,
    // subtask
    required String? prompt,
    required String? description,
    required String? agent,
    // agent
    required String? agentName,
    // retry
    required int? attempt,
    required String? retryError,
  }) = _PluginMessagePart;
}

@freezed
sealed class PluginToolState with _$PluginToolState {
  const factory PluginToolState({
    required String status,
    required String? title,
    required String? output,
    required String? error,
  }) = _PluginToolState;
}

/// Sealed class representing a plugin-level message.
///
/// Three variants:
/// - [PluginMessageUser]: a message sent by the user
/// - [PluginMessageAssistant]: a regular assistant response
/// - [PluginMessageError]: an assistant message that failed with an error
///
/// The JSON serialization uses `"role"` as the union key.
@Freezed(unionKey: "role")
sealed class PluginMessage with _$PluginMessage {
  const factory PluginMessage.user({
    required String id,
    required String sessionID,
    required String? agent,
  }) = PluginMessageUser;

  const factory PluginMessage.assistant({
    required String id,
    required String sessionID,
    required String? agent,
    required String? modelID,
    required String? providerID,
  }) = PluginMessageAssistant;

  const factory PluginMessage.error({
    required String id,
    required String sessionID,
    required String? agent,
    required String? modelID,
    required String? providerID,
    required String errorName,
    required String errorMessage,
  }) = PluginMessageError;
}
