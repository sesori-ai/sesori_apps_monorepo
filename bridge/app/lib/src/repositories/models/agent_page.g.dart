// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_page.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgentPageAnswered _$AgentPageAnsweredFromJson(Map json) => AgentPageAnswered(
  answers: (json['answers'] as List<dynamic>)
      .map((e) => PageAnswer.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
  note: json['note'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$AgentPageAnsweredToJson(AgentPageAnswered instance) =>
    <String, dynamic>{
      'answers': instance.answers.map((e) => e.toJson()).toList(),
      'note': ?instance.note,
      'type': instance.$type,
    };

AgentPageDismissed _$AgentPageDismissedFromJson(Map json) =>
    AgentPageDismissed($type: json['type'] as String?);

Map<String, dynamic> _$AgentPageDismissedToJson(AgentPageDismissed instance) =>
    <String, dynamic>{'type': instance.$type};
