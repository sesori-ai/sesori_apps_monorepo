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

@Freezed(fromJson: true, toJson: false)
sealed class CodexFileChangeParamsDto with _$CodexFileChangeParamsDto {
  const factory({
    required String? threadId,
    required String? turnId,
    required CodexFileChangeItemDto item,
  }) = _CodexFileChangeParamsDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexFileChangeParamsDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class CodexFileChangeItemDto with _$CodexFileChangeItemDto {
  const factory({
    @JsonKey(
      unknownEnumValue: CodexFileChangeItemType.unknown,
      defaultValue: CodexFileChangeItemType.unknown,
    )
    required CodexFileChangeItemType type,
    required String? id,
    @JsonKey(fromJson: _fileChangeStatusFromJson) required CodexFileChangeStatus status,
    @JsonKey(fromJson: _fileChangeEntriesFromJson) required List<CodexFileChangeEntryDto> changes,
  }) = _CodexFileChangeItemDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexFileChangeItemDtoFromJson(json);
}

/// One `{path, kind, diff}` entry of a `fileChange` item.
@Freezed(fromJson: true, toJson: false)
sealed class CodexFileChangeEntryDto with _$CodexFileChangeEntryDto {
  const factory({
    @JsonKey(fromJson: _stringOrNull) required String? path,
    @JsonKey(fromJson: _stringOrNull) required String? diff,
  }) = _CodexFileChangeEntryDto;

  factory fromJson(Map<String, dynamic> json) => _$CodexFileChangeEntryDtoFromJson(json);
}

String? _stringOrNull(Object? value) => value is String ? value : null;

/// An entry that is not an object still counts as a change, with neither a
/// path nor a diff.
List<CodexFileChangeEntryDto> _fileChangeEntriesFromJson(Object? value) {
  if (value is! List) return const [];
  return [
    for (final Object? entry in value)
      if (entry case final Map<String, dynamic> json)
        CodexFileChangeEntryDto.fromJson(json)
      else
        const CodexFileChangeEntryDto(path: null, diff: null),
  ];
}
