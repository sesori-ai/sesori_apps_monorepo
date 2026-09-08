// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_thread_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CodexThreadEnvelopeDto _$CodexThreadEnvelopeDtoFromJson(Map json) =>
    _CodexThreadEnvelopeDto(
      thread: json['thread'] == null
          ? null
          : CodexThreadDto.fromJson(
              Map<String, dynamic>.from(json['thread'] as Map),
            ),
      model: json['model'] as String?,
      modelProvider: json['modelProvider'] as String?,
      cwd: json['cwd'] as String?,
    );

_CodexThreadTurnDto _$CodexThreadTurnDtoFromJson(Map json) =>
    _CodexThreadTurnDto(
      id: json['id'] as String?,
      items:
          (json['items'] as List<dynamic>?)
              ?.map(
                (e) => CodexThreadItemDto.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          [],
    );

CodexThreadUserMessageItemDto _$CodexThreadUserMessageItemDtoFromJson(
  Map json,
) => CodexThreadUserMessageItemDto(
  content:
      (json['content'] as List<dynamic>?)
          ?.map(
            (e) => CodexThreadContentDto.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList() ??
      [],
  $type: json['type'] as String?,
);

CodexThreadUnknownItemDto _$CodexThreadUnknownItemDtoFromJson(Map json) =>
    CodexThreadUnknownItemDto($type: json['type'] as String?);

CodexThreadTextContentDto _$CodexThreadTextContentDtoFromJson(Map json) =>
    CodexThreadTextContentDto(
      text: json['text'] as String,
      $type: json['type'] as String?,
    );

CodexThreadUnknownContentDto _$CodexThreadUnknownContentDtoFromJson(Map json) =>
    CodexThreadUnknownContentDto($type: json['type'] as String?);

_CodexThreadDto _$CodexThreadDtoFromJson(Map json) => _CodexThreadDto(
  id: json['id'] as String?,
  name: json['name'] as String?,
  cwd: json['cwd'] as String?,
  createdAt: json['createdAt'] as num?,
  updatedAt: json['updatedAt'] as num?,
  modelProvider: json['modelProvider'] as String?,
  parentThreadId: json['parentThreadId'] as String?,
  agentNickname: json['agentNickname'] as String?,
  agentRole: json['agentRole'] as String?,
  threadSource: $enumDecodeNullable(
    _$CodexThreadSourceEnumMap,
    json['threadSource'],
    unknownValue: CodexThreadSource.unknown,
  ),
  turns:
      (json['turns'] as List<dynamic>?)
          ?.map(
            (e) => CodexThreadTurnDto.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList() ??
      [],
);

const _$CodexThreadSourceEnumMap = {
  CodexThreadSource.subAgent: 'subAgent',
  CodexThreadSource.subAgentReview: 'subAgentReview',
  CodexThreadSource.subAgentCompact: 'subAgentCompact',
  CodexThreadSource.subAgentThreadSpawn: 'subAgentThreadSpawn',
  CodexThreadSource.subAgentOther: 'subAgentOther',
  CodexThreadSource.unknown: 'unknown',
};
