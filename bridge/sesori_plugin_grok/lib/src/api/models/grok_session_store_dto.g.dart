// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grok_session_store_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GrokSessionSummaryDto _$GrokSessionSummaryDtoFromJson(Map json) =>
    _GrokSessionSummaryDto(
      info: json['info'] == null
          ? null
          : GrokSessionSummaryInfoDto.fromJson(
              Map<String, dynamic>.from(json['info'] as Map),
            ),
      sessionKind: $enumDecodeNullable(
        _$GrokSessionKindEnumMap,
        json['session_kind'],
        unknownValue: GrokSessionKind.unknown,
      ),
      agentName: json['agent_name'] as String?,
      generatedTitle: json['generated_title'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );

const _$GrokSessionKindEnumMap = {
  GrokSessionKind.build: 'build',
  GrokSessionKind.subagent: 'subagent',
  GrokSessionKind.unknown: 'unknown',
};

_GrokSessionSummaryInfoDto _$GrokSessionSummaryInfoDtoFromJson(Map json) =>
    _GrokSessionSummaryInfoDto(
      id: json['id'] as String?,
      cwd: json['cwd'] as String?,
    );

GrokPersistedSessionUpdateDto _$GrokPersistedSessionUpdateDtoFromJson(
  Map json,
) => GrokPersistedSessionUpdateDto(
  params: GrokSessionNotificationDto.fromJson(
    Map<String, dynamic>.from(json['params'] as Map),
  ),
  $type: json['method'] as String?,
);

GrokPersistedUpdateUnknownDto _$GrokPersistedUpdateUnknownDtoFromJson(
  Map json,
) => GrokPersistedUpdateUnknownDto($type: json['method'] as String?);
