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
    required String? text,
    required String? tool,
    required ToolState? state,
    required String? prompt,
    required String? description,
    required String? agent,
    required String? agentName,
    required int? attempt,
    required String? retryError,
  }) = _MessagePart;

  factory MessagePart.fromJson(Map<String, dynamic> json) => _$MessagePartFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class ToolState with _$ToolState {
  const factory ToolState({
    required String status,
    required String? title,
    required String? output,
    required String? error,
  }) = _ToolState;

  factory ToolState.fromJson(Map<String, dynamic> json) => _$ToolStateFromJson(json);
}
