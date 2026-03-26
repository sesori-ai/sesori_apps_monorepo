import "package:freezed_annotation/freezed_annotation.dart";

part "message_part.freezed.dart";

part "message_part.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class MessagePart with _$MessagePart {
  const factory MessagePart({
    required String id,
    required String sessionID,
    required String messageID,
    required String type,
    String? text,
    String? tool,
    ToolState? state,
    String? prompt,
    String? description,
    String? agent,
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
