import "package:freezed_annotation/freezed_annotation.dart";

part "message_part.freezed.dart";

part "message_part.g.dart";

@JsonEnum()
enum MessagePartType {
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
}

@Freezed(fromJson: true, toJson: true)
sealed class MessagePart with _$MessagePart {
  const factory MessagePart({
    required String id,
    required String sessionID,
    required String messageID,
    required MessagePartType type,
    String? text,
    String? tool,
    ToolState? state,
    String? prompt,
    String? description,
    String? agent,
    // agent
    String? agentName,
    // retry
    int? attempt,
    String? retryError,
  }) = _MessagePart;

  factory MessagePart.fromJson(Map<String, dynamic> json) => _$MessagePartFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class ToolState with _$ToolState {
  const factory ToolState({
    required String status,
    String? title,
    String? output,
    String? error,
  }) = _ToolState;

  factory ToolState.fromJson(Map<String, dynamic> json) => _$ToolStateFromJson(json);
}
