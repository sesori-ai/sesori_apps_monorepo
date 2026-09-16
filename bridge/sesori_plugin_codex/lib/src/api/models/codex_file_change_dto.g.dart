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
      changes:
          (json['changes'] as List<dynamic>?)
              ?.map(
                (e) => CodexFileUpdateDto.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const [],
    );

Map<String, dynamic> _$CodexFileChangeItemDtoToJson(
  _CodexFileChangeItemDto instance,
) => <String, dynamic>{
  'type': _$CodexFileChangeItemTypeEnumMap[instance.type]!,
  'id': ?instance.id,
  'status': _$CodexFileChangeStatusEnumMap[instance.status]!,
  'changes': instance.changes.map((e) => e.toJson()).toList(),
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

_CodexFileUpdateDto _$CodexFileUpdateDtoFromJson(Map json) =>
    _CodexFileUpdateDto(
      path: json['path'] as String,
      kind: CodexFileUpdateKindDto.fromJson(
        Map<String, dynamic>.from(json['kind'] as Map),
      ),
    );

Map<String, dynamic> _$CodexFileUpdateDtoToJson(_CodexFileUpdateDto instance) =>
    <String, dynamic>{'path': instance.path, 'kind': instance.kind.toJson()};

_CodexFileUpdateKindDto _$CodexFileUpdateKindDtoFromJson(Map json) =>
    _CodexFileUpdateKindDto(
      type: $enumDecode(
        _$CodexFileUpdateKindEnumMap,
        json['type'],
        unknownValue: CodexFileUpdateKind.unknown,
      ),
      movePath: json['move_path'] as String?,
    );

Map<String, dynamic> _$CodexFileUpdateKindDtoToJson(
  _CodexFileUpdateKindDto instance,
) => <String, dynamic>{
  'type': _$CodexFileUpdateKindEnumMap[instance.type]!,
  'move_path': ?instance.movePath,
};

const _$CodexFileUpdateKindEnumMap = {
  CodexFileUpdateKind.add: 'add',
  CodexFileUpdateKind.update: 'update',
  CodexFileUpdateKind.delete: 'delete',
  CodexFileUpdateKind.unknown: 'unknown',
};
