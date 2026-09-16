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

GrokPersistedGrokSessionUpdateDto _$GrokPersistedGrokSessionUpdateDtoFromJson(
  Map json,
) => GrokPersistedGrokSessionUpdateDto(
  params: GrokSessionNotificationDto.fromJson(
    Map<String, dynamic>.from(json['params'] as Map),
  ),
  $type: json['method'] as String?,
);

GrokPersistedAcpSessionUpdateDto _$GrokPersistedAcpSessionUpdateDtoFromJson(
  Map json,
) => GrokPersistedAcpSessionUpdateDto(
  params: GrokPersistedAcpNotificationDto.fromJson(
    Map<String, dynamic>.from(json['params'] as Map),
  ),
  $type: json['method'] as String?,
);

GrokPersistedUpdateUnknownDto _$GrokPersistedUpdateUnknownDtoFromJson(
  Map json,
) => GrokPersistedUpdateUnknownDto($type: json['method'] as String?);

_GrokPersistedAcpNotificationDto _$GrokPersistedAcpNotificationDtoFromJson(
  Map json,
) => _GrokPersistedAcpNotificationDto(
  sessionId: json['sessionId'] as String,
  update: GrokPersistedAcpUpdateDto.fromJson(
    Map<String, dynamic>.from(json['update'] as Map),
  ),
);

GrokPersistedUserMessageChunkDto _$GrokPersistedUserMessageChunkDtoFromJson(
  Map json,
) => GrokPersistedUserMessageChunkDto(
  content: GrokPersistedContentDto.fromJson(
    Map<String, dynamic>.from(json['content'] as Map),
  ),
  $type: json['sessionUpdate'] as String?,
);

GrokPersistedAcpUpdateUnknownDto _$GrokPersistedAcpUpdateUnknownDtoFromJson(
  Map json,
) => GrokPersistedAcpUpdateUnknownDto($type: json['sessionUpdate'] as String?);

GrokPersistedTextContentDto _$GrokPersistedTextContentDtoFromJson(Map json) =>
    GrokPersistedTextContentDto(
      text: json['text'] as String,
      $type: json['type'] as String?,
    );

GrokPersistedContentUnknownDto _$GrokPersistedContentUnknownDtoFromJson(
  Map json,
) => GrokPersistedContentUnknownDto($type: json['type'] as String?);
