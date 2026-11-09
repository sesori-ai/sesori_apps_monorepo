// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_mcp_elicitation_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CodexMcpElicitationDto _$CodexMcpElicitationDtoFromJson(Map json) =>
    _CodexMcpElicitationDto(
      threadId: json['threadId'] as String,
      serverName: json['serverName'] as String,
      mode: $enumDecode(
        _$CodexMcpElicitationModeEnumMap,
        json['mode'],
        unknownValue: CodexMcpElicitationMode.unknown,
      ),
      message: json['message'] as String?,
      requestedSchema: (json['requestedSchema'] as Map?)?.map(
        (k, e) => MapEntry(k as String, e),
      ),
      url: json['url'] as String?,
      elicitationId: json['elicitationId'] as String?,
    );

const _$CodexMcpElicitationModeEnumMap = {
  CodexMcpElicitationMode.form: 'form',
  CodexMcpElicitationMode.url: 'url',
  CodexMcpElicitationMode.unknown: 'unknown',
};
