import "package:freezed_annotation/freezed_annotation.dart";

part "cursor_task_dto.freezed.dart";
part "cursor_task_dto.g.dart";

enum CursorTaskTool() {
  @JsonValue("task")
  task,
  @JsonValue("unknown")
  unknown,
}

enum CursorSubagentType() {
  @JsonValue("unspecified")
  unspecified,
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

/// Cursor's observed closed sub-agent presentation variant.
@Freezed(fromJson: true, toJson: false)
sealed class CursorSubagentTypeDto with _$CursorSubagentTypeDto {
  const factory({
    @JsonKey(unknownEnumValue: CursorSubagentType.unknown) required CursorSubagentType? custom,
  }) = _CursorSubagentTypeDto;

  factory fromJson(Map<String, dynamic> json) => _$CursorSubagentTypeDtoFromJson(json);
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
