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
    // text / reasoning
    String? text,
    // tool
    String? tool,
    String? callID,
    ToolState? state,
    // file
    String? mime,
    String? url,
    String? filename,
    // step-finish
    double? cost,
    String? reason,
    // subtask
    String? prompt,
    String? description,
    String? agent,
    // snapshot / step-start
    String? snapshot,
    // time (for text, reasoning, tool)
    PartTime? time,
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

@Freezed(fromJson: true, toJson: true)
sealed class PartTime with _$PartTime {
  const factory PartTime({
    int? start,
    int? end,
  }) = _PartTime;

  factory PartTime.fromJson(Map<String, dynamic> json) => _$PartTimeFromJson(json);
}
