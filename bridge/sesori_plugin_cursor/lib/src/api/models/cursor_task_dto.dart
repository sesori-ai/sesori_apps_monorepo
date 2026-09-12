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

/// Cursor-owned boundary model for identifying standard Task calls.
@Freezed(fromJson: true, toJson: false)
sealed class CursorTaskInputDto with _$CursorTaskInputDto {
  const factory({
    @JsonKey(
      name: "_toolName",
      unknownEnumValue: CursorTaskTool.unknown,
    )
    required CursorTaskTool toolName,
  }) = _CursorTaskInputDto;

  factory fromJson(Map<String, dynamic> json) => _$CursorTaskInputDtoFromJson(json);
}

/// Explicit terminal mode fact from a standard Task update.
@Freezed(fromJson: true, toJson: false)
sealed class CursorTaskOutputDto with _$CursorTaskOutputDto {
  const factory({required bool isBackground}) = _CursorTaskOutputDto;

  factory fromJson(Map<String, dynamic> json) => _$CursorTaskOutputDtoFromJson(json);
}

/// Cursor's observed tagged sub-agent presentation variant.
@Freezed(fromJson: true, toJson: false)
sealed class CursorSubagentTypeDto with _$CursorSubagentTypeDto {
  const factory({required CursorSubagentCustomTypeDto? custom}) = _CursorSubagentTypeDto;

  factory fromJson(Map<String, dynamic> json) => _$CursorSubagentTypeDtoFromJson(json);
}

/// Payload of Cursor's observed live `custom` sub-agent type variant.
@Freezed(fromJson: true, toJson: false)
sealed class CursorSubagentCustomTypeDto with _$CursorSubagentCustomTypeDto {
  const factory({required CursorSubagentUnspecifiedDto? unspecified}) = _CursorSubagentCustomTypeDto;

  factory fromJson(Map<String, dynamic> json) => _$CursorSubagentCustomTypeDtoFromJson(json);
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

/// Presentation and exact tool correlation from Cursor's terminal
/// `cursor/task` request. Agent/model identifiers are deliberately omitted:
/// Cursor exposes no child session, and they are not presentation authority.
@Freezed(fromJson: true, toJson: false)
sealed class CursorTaskRequestDto with _$CursorTaskRequestDto {
  const factory({
    required String toolCallId,
    required String description,
    required String prompt,
    required CursorSubagentTypeDto subagentType,
  }) = _CursorTaskRequestDto;

  factory fromJson(Map<String, dynamic> json) => _$CursorTaskRequestDtoFromJson(json);
}
