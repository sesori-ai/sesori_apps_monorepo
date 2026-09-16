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
    @Default([]) List<CodexFileUpdateDto> changes,
  }) = _CodexFileChangeItemDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexFileChangeItemDtoFromJson(json);
}

enum CodexFileUpdateKind() {
  add,
  update,
  delete,
  unknown,
}

@Freezed(fromJson: true, toJson: true)
sealed class CodexFileUpdateDto with _$CodexFileUpdateDto {
  const factory({required String path, required CodexFileUpdateKindDto kind}) = _CodexFileUpdateDto;
  factory fromJson(Map<String, dynamic> json) => _$CodexFileUpdateDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class CodexFileUpdateKindDto with _$CodexFileUpdateKindDto {
  const factory({
    @JsonKey(unknownEnumValue: CodexFileUpdateKind.unknown) required CodexFileUpdateKind type,
    @JsonKey(name: "move_path") required String? movePath,
  }) = _CodexFileUpdateKindDto;
  factory fromJson(Map<String, dynamic> json) => _$CodexFileUpdateKindDtoFromJson(json);
}
