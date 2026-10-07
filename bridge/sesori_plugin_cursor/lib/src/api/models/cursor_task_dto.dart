import "package:freezed_annotation/freezed_annotation.dart";

part "cursor_task_dto.freezed.dart";
part "cursor_task_dto.g.dart";

enum CursorTaskTool() {
  @JsonValue("task")
  task,
  @JsonValue("unknown")
  unknown,
}

enum CursorTaskReplayUpdateKind() {
  @JsonValue("tool_call")
  toolCall,
  @JsonValue("tool_call_update")
  toolCallUpdate,
  @JsonValue("unknown")
  unknown,
}

enum CursorTaskReplayStatus() {
  @JsonValue("pending")
  pending,
  @JsonValue("in_progress")
  inProgress,
  @JsonValue("completed")
  completed,
  @JsonValue("failed")
  failed,
  @JsonValue("unknown")
  unknown,
}

/// Cursor-owned boundary model for a standard Task call's `rawInput`: it
/// identifies the call as a sub-agent spawn and carries the spawn's prompt,
/// which Cursor's `subagent_spawned` notification does not repeat.
@Freezed(fromJson: true, toJson: false)
sealed class CursorTaskInputDto with _$CursorTaskInputDto {
  const factory({
    @JsonKey(
      name: "_toolName",
      unknownEnumValue: CursorTaskTool.unknown,
    )
    required CursorTaskTool toolName,
    required String? prompt,
    required String? description,
  }) = _CursorTaskInputDto;

  factory fromJson(Map<String, dynamic> json) => _$CursorTaskInputDtoFromJson(json);
}

/// Explicit terminal mode fact from a standard Task update.
@Freezed(fromJson: true, toJson: false)
sealed class CursorTaskOutputDto with _$CursorTaskOutputDto {
  const factory({required bool isBackground}) = _CursorTaskOutputDto;

  factory fromJson(Map<String, dynamic> json) => _$CursorTaskOutputDtoFromJson(json);
}

/// Empty payload marking Cursor's observed `unspecified` custom sub-agent.
@Freezed(fromJson: true, toJson: false)
sealed class CursorSubagentUnspecifiedDto with _$CursorSubagentUnspecifiedDto {
  const factory() = _CursorSubagentUnspecifiedDto;

  factory fromJson(Map<String, dynamic> json) => _$CursorSubagentUnspecifiedDtoFromJson(json);
}

/// Cursor's replay-only sub-agent presentation shape.
@Freezed(fromJson: true, toJson: false)
sealed class CursorTaskReplaySubagentTypeDto with _$CursorTaskReplaySubagentTypeDto {
  const factory({required CursorSubagentUnspecifiedDto? unspecified}) = _CursorTaskReplaySubagentTypeDto;

  factory fromJson(Map<String, dynamic> json) => _$CursorTaskReplaySubagentTypeDtoFromJson(json);
}

/// Full standard Task input persisted by Cursor for history replay.
@Freezed(fromJson: true, toJson: false)
sealed class CursorTaskReplayInputDto with _$CursorTaskReplayInputDto {
  const factory({
    @JsonKey(
      name: "_toolName",
      unknownEnumValue: CursorTaskTool.unknown,
    )
    required CursorTaskTool toolName,
    required String? prompt,
    required String? description,
    required CursorTaskReplaySubagentTypeDto? subagentType,
  }) = _CursorTaskReplayInputDto;

  factory fromJson(Map<String, dynamic> json) => _$CursorTaskReplayInputDtoFromJson(json);
}

/// Minimal standard update envelope used to establish replay Task identity.
@Freezed(fromJson: true, toJson: false)
sealed class CursorTaskReplayUpdateDto with _$CursorTaskReplayUpdateDto {
  const factory({
    @JsonKey(unknownEnumValue: CursorTaskReplayUpdateKind.unknown) required CursorTaskReplayUpdateKind sessionUpdate,
    required String? toolCallId,
    @JsonKey(unknownEnumValue: CursorTaskReplayStatus.unknown) required CursorTaskReplayStatus? status,
  }) = _CursorTaskReplayUpdateDto;

  factory fromJson(Map<String, dynamic> json) => _$CursorTaskReplayUpdateDtoFromJson(json);
}
