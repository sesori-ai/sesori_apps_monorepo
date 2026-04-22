// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_session_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CreateSessionRequest _$CreateSessionRequestFromJson(Map json) =>
    _CreateSessionRequest(
      projectId: json['projectId'] as String,
      parts: (json['parts'] as List<dynamic>)
          .map((e) => PromptPart.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      agent: json['agent'] as String?,
      model: json['model'] == null
          ? null
          : PromptModel.fromJson(
              Map<String, dynamic>.from(json['model'] as Map),
            ),
      command: json['command'] as String?,
      effort: $enumDecodeNullable(_$SessionEffortEnumMap, json['effort']),
      dedicatedWorktree: json['dedicatedWorktree'] as bool,
    );

Map<String, dynamic> _$CreateSessionRequestToJson(
  _CreateSessionRequest instance,
) => <String, dynamic>{
  'projectId': instance.projectId,
  'parts': instance.parts.map((e) => e.toJson()).toList(),
  'agent': instance.agent,
  'model': instance.model?.toJson(),
  'command': instance.command,
  'effort': _$SessionEffortEnumMap[instance.effort],
  'dedicatedWorktree': instance.dedicatedWorktree,
};

const _$SessionEffortEnumMap = {
  SessionEffort.low: 'low',
  SessionEffort.medium: 'medium',
  SessionEffort.max: 'max',
};
