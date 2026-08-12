import "package:freezed_annotation/freezed_annotation.dart";

part "codex_file_change_dto.freezed.dart";
part "codex_file_change_dto.g.dart";

enum CodexFileChangeItemType() {
  @JsonValue("fileChange")
  fileChange,
  unknown,
}

enum CodexFileChangeStatus() {
  inProgress,
  completed,
  failed,
  declined,
  unknown,
}

CodexFileChangeStatus _fileChangeStatusFromJson(Object? value) {
  return switch (value) {
    "inProgress" => CodexFileChangeStatus.inProgress,
    "completed" => CodexFileChangeStatus.completed,
    "failed" => CodexFileChangeStatus.failed,
    "declined" => CodexFileChangeStatus.declined,
    _ => CodexFileChangeStatus.unknown,
  };
}

@freezed
sealed class CodexFileChangeParamsDto with _$CodexFileChangeParamsDto {
  const factory({
    required String? threadId,
    required String? turnId,
    required CodexFileChangeItemDto item,
  }) = _CodexFileChangeParamsDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexFileChangeParamsDtoFromJson(json);
}

@freezed
sealed class CodexFileChangeItemDto with _$CodexFileChangeItemDto {
  const factory({
    @JsonKey(
      unknownEnumValue: CodexFileChangeItemType.unknown,
      defaultValue: CodexFileChangeItemType.unknown,
    )
    required CodexFileChangeItemType type,
    required String? id,
    @JsonKey(fromJson: _fileChangeStatusFromJson) required CodexFileChangeStatus status,
  }) = _CodexFileChangeItemDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexFileChangeItemDtoFromJson(json);
}
