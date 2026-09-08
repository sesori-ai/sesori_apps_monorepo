// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'codex_tool_outcome_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CodexToolOutcomeFileDto _$CodexToolOutcomeFileDtoFromJson(Map json) =>
    _CodexToolOutcomeFileDto(
      schemaVersion: (json['schemaVersion'] as num).toInt(),
      errors: (json['errors'] as List<dynamic>)
          .map(
            (e) => CodexStoredToolErrorDto.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );

Map<String, dynamic> _$CodexToolOutcomeFileDtoToJson(
  _CodexToolOutcomeFileDto instance,
) => <String, dynamic>{
  'schemaVersion': instance.schemaVersion,
  'errors': instance.errors.map((e) => e.toJson()).toList(),
};

_CodexStoredToolErrorDto _$CodexStoredToolErrorDtoFromJson(Map json) =>
    _CodexStoredToolErrorDto(
      sessionId: json['sessionId'] as String,
      callId: json['callId'] as String,
    );

Map<String, dynamic> _$CodexStoredToolErrorDtoToJson(
  _CodexStoredToolErrorDto instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'callId': instance.callId,
};
