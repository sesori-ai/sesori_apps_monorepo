// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'v2_request_bodies.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$V2CreateSessionBodyToJson(
  _V2CreateSessionBody instance,
) => <String, dynamic>{
  'location': instance.location.toJson(),
  'title': ?instance.title,
  'agent': ?instance.agent,
  'model': ?instance.model?.toJson(),
};

Map<String, dynamic> _$V2RenameSessionBodyToJson(
  _V2RenameSessionBody instance,
) => <String, dynamic>{'title': instance.title};

Map<String, dynamic> _$V2SwitchAgentBodyToJson(_V2SwitchAgentBody instance) =>
    <String, dynamic>{'agent': instance.agent};

Map<String, dynamic> _$V2SwitchModelBodyToJson(_V2SwitchModelBody instance) =>
    <String, dynamic>{'model': instance.model.toJson()};

Map<String, dynamic> _$V2PromptBodyToJson(_V2PromptBody instance) =>
    <String, dynamic>{
      'id': ?instance.id,
      'text': instance.text,
      'files': ?instance.files?.map((e) => e.toJson()).toList(),
      'agents': ?instance.agents?.map((e) => e.toJson()).toList(),
      'skills': ?instance.skills?.map((e) => e.toJson()).toList(),
      'delivery': ?instance.delivery?.toJson(),
      'resume': ?instance.resume,
    };

Map<String, dynamic> _$V2CommandBodyToJson(_V2CommandBody instance) =>
    <String, dynamic>{
      'name': instance.name,
      'text': instance.text,
      'files': ?instance.files?.map((e) => e.toJson()).toList(),
      'agents': ?instance.agents?.map((e) => e.toJson()).toList(),
      'skills': ?instance.skills?.map((e) => e.toJson()).toList(),
      'delivery': ?instance.delivery?.toJson(),
    };

Map<String, dynamic> _$V2SyntheticBodyToJson(_V2SyntheticBody instance) =>
    <String, dynamic>{
      'id': ?instance.id,
      'text': instance.text,
      'description': ?instance.description,
      'delivery': ?instance.delivery?.toJson(),
      'resume': ?instance.resume,
    };

Map<String, dynamic> _$V2CompactBodyToJson(_V2CompactBody instance) =>
    <String, dynamic>{
      'id': ?instance.id,
      'delivery': ?instance.delivery?.toJson(),
    };

Map<String, dynamic> _$V2PermissionReplyBodyToJson(
  _V2PermissionReplyBody instance,
) => <String, dynamic>{
  'decision': instance.decision.toJson(),
  'message': ?instance.message,
};

Map<String, dynamic> _$V2UpdateProjectBodyToJson(
  _V2UpdateProjectBody instance,
) => <String, dynamic>{
  'canonical': ?instance.canonical,
  'name': ?instance.name,
  'icon': ?instance.icon?.toJson(),
  'commands': ?instance.commands?.toJson(),
};
