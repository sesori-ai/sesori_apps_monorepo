// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hermes_replay_update_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_HermesReplayUpdateDto _$HermesReplayUpdateDtoFromJson(Map json) =>
    _HermesReplayUpdateDto(
      sessionUpdate: json['sessionUpdate'] as String?,
      meta: json['_meta'] == null
          ? null
          : HermesUpdateMetaDto.fromJson(
              Map<String, dynamic>.from(json['_meta'] as Map),
            ),
      content: json['content'] == null
          ? null
          : HermesTextContentDto.fromJson(
              Map<String, dynamic>.from(json['content'] as Map),
            ),
    );

Map<String, dynamic> _$HermesReplayUpdateDtoToJson(
  _HermesReplayUpdateDto instance,
) => <String, dynamic>{
  'sessionUpdate': ?instance.sessionUpdate,
  '_meta': ?instance.meta?.toJson(),
  'content': ?instance.content?.toJson(),
};

_HermesUpdateMetaDto _$HermesUpdateMetaDtoFromJson(Map json) =>
    _HermesUpdateMetaDto(
      hermes: json['hermes'] == null
          ? null
          : HermesMetaDto.fromJson(
              Map<String, dynamic>.from(json['hermes'] as Map),
            ),
    );

Map<String, dynamic> _$HermesUpdateMetaDtoToJson(
  _HermesUpdateMetaDto instance,
) => <String, dynamic>{'hermes': ?instance.hermes?.toJson()};

_HermesMetaDto _$HermesMetaDtoFromJson(Map json) =>
    _HermesMetaDto(compactionSummary: json['compactionSummary'] as bool?);

Map<String, dynamic> _$HermesMetaDtoToJson(_HermesMetaDto instance) =>
    <String, dynamic>{'compactionSummary': ?instance.compactionSummary};

_HermesTextContentDto _$HermesTextContentDtoFromJson(Map json) =>
    _HermesTextContentDto(
      type: json['type'] as String?,
      text: json['text'] as String?,
    );

Map<String, dynamic> _$HermesTextContentDtoToJson(
  _HermesTextContentDto instance,
) => <String, dynamic>{'type': ?instance.type, 'text': ?instance.text};
