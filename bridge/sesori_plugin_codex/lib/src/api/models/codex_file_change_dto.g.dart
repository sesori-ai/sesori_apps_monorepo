// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_file_change_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CodexFileChangeParamsDto _$CodexFileChangeParamsDtoFromJson(Map json) =>
    _CodexFileChangeParamsDto(
      threadId: json['threadId'] as String?,
      turnId: json['turnId'] as String?,
      item: CodexFileChangeItemDto.fromJson(
        Map<String, dynamic>.from(json['item'] as Map),
      ),
    );

Map<String, dynamic> _$CodexFileChangeParamsDtoToJson(
  _CodexFileChangeParamsDto instance,
) => <String, dynamic>{
  'threadId': ?instance.threadId,
  'turnId': ?instance.turnId,
  'item': instance.item.toJson(),
};

_CodexFileChangeItemDto _$CodexFileChangeItemDtoFromJson(Map json) =>
    _CodexFileChangeItemDto(
      type:
          $enumDecodeNullable(
            _$CodexFileChangeItemTypeEnumMap,
            json['type'],
            unknownValue: CodexFileChangeItemType.unknown,
          ) ??
          CodexFileChangeItemType.unknown,
      id: json['id'] as String?,
      status: _fileChangeStatusFromJson(json['status']),
    );

Map<String, dynamic> _$CodexFileChangeItemDtoToJson(
  _CodexFileChangeItemDto instance,
) => <String, dynamic>{
  'type': _$CodexFileChangeItemTypeEnumMap[instance.type]!,
  'id': ?instance.id,
  'status': _$CodexFileChangeStatusEnumMap[instance.status]!,
};

const _$CodexFileChangeItemTypeEnumMap = {
  CodexFileChangeItemType.fileChange: 'fileChange',
  CodexFileChangeItemType.unknown: 'unknown',
};

const _$CodexFileChangeStatusEnumMap = {
  CodexFileChangeStatus.inProgress: 'inProgress',
  CodexFileChangeStatus.completed: 'completed',
  CodexFileChangeStatus.failed: 'failed',
  CodexFileChangeStatus.declined: 'declined',
  CodexFileChangeStatus.unknown: 'unknown',
};
