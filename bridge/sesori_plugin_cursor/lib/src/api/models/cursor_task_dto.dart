import "package:freezed_annotation/freezed_annotation.dart";

part "cursor_task_dto.freezed.dart";
part "cursor_task_dto.g.dart";

enum CursorTaskTool() {
  @JsonValue("task")
  task,
  @JsonValue("unknown")
  unknown,
}

/// Minimal Cursor-owned boundary model for identifying standard Task calls.
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
