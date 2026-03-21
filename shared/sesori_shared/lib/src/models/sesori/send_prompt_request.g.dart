// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'send_prompt_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SendPromptRequest _$SendPromptRequestFromJson(Map json) => _SendPromptRequest(
  parts: (json['parts'] as List<dynamic>)
      .map((e) => PromptPart.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
  agent: json['agent'] as String?,
  model: json['model'] == null
      ? null
      : PromptModel.fromJson(Map<String, dynamic>.from(json['model'] as Map)),
);

Map<String, dynamic> _$SendPromptRequestToJson(_SendPromptRequest instance) =>
    <String, dynamic>{
      'parts': instance.parts.map((e) => e.toJson()).toList(),
      'agent': instance.agent,
      'model': instance.model?.toJson(),
    };

PromptPartText _$PromptPartTextFromJson(Map json) =>
    PromptPartText(text: json['text'] as String);

Map<String, dynamic> _$PromptPartTextToJson(PromptPartText instance) =>
    <String, dynamic>{'text': instance.text};

_PromptModel _$PromptModelFromJson(Map json) => _PromptModel(
  providerID: json['providerID'] as String,
  modelID: json['modelID'] as String,
);

Map<String, dynamic> _$PromptModelToJson(_PromptModel instance) =>
    <String, dynamic>{
      'providerID': instance.providerID,
      'modelID': instance.modelID,
    };
