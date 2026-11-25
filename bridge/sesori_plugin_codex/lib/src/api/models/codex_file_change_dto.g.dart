// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_file_change_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CodexFileChangeParamsDto _$CodexFileChangeParamsDtoFromJson(Map json) => _CodexFileChangeParamsDto(
  threadId: json['threadId'] as String?,
  turnId: json['turnId'] as String?,
  item: CodexFileChangeItemDto.fromJson(
    Map<String, dynamic>.from(json['item'] as Map),
  ),
);

_CodexFileChangeItemDto _$CodexFileChangeItemDtoFromJson(Map json) => _CodexFileChangeItemDto(
  type:
      $enumDecodeNullable(
        _$CodexFileChangeItemTypeEnumMap,
        json['type'],
        unknownValue: CodexFileChangeItemType.unknown,
      ) ??
      CodexFileChangeItemType.unknown,
  id: json['id'] as String?,
  status: _fileChangeStatusFromJson(json['status']),
  changes: _fileChangeEntriesFromJson(json['changes']),
);

const _$CodexFileChangeItemTypeEnumMap = {
  CodexFileChangeItemType.fileChange: 'fileChange',
  CodexFileChangeItemType.unknown: 'unknown',
};

_CodexFileChangeEntryDto _$CodexFileChangeEntryDtoFromJson(Map json) => _CodexFileChangeEntryDto(
  path: _stringOrNull(json['path']),
  diff: _stringOrNull(json['diff']),
);
