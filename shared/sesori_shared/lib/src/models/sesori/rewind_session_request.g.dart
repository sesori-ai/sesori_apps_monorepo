// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rewind_session_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RewindSessionRequest _$RewindSessionRequestFromJson(Map json) =>
    _RewindSessionRequest(
      sessionId: json['sessionId'] as String,
      messageId: json['messageId'] as String,
      promptId: json['promptId'] as String,
      parts: (json['parts'] as List<dynamic>)
          .map((e) => PromptPart.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      agent: json['agent'] as String?,
      model: json['model'] == null
          ? null
          : PromptModel.fromJson(
              Map<String, dynamic>.from(json['model'] as Map),
            ),
      variant: json['variant'] == null
          ? null
          : SessionVariant.fromJson(
              Map<String, dynamic>.from(json['variant'] as Map),
            ),
      fastMode: json['fastMode'] as bool,
    );

Map<String, dynamic> _$RewindSessionRequestToJson(
  _RewindSessionRequest instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'messageId': instance.messageId,
  'promptId': instance.promptId,
  'parts': instance.parts.map((e) => e.toJson()).toList(),
  'agent': ?instance.agent,
  'model': ?instance.model?.toJson(),
  'variant': ?instance.variant?.toJson(),
  'fastMode': instance.fastMode,
};
