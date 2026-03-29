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

PromptPartText _$PromptPartTextFromJson(Map json) => PromptPartText(
  text: json['text'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$PromptPartTextToJson(PromptPartText instance) =>
    <String, dynamic>{'text': instance.text, 'type': instance.$type};

PromptPartFilePath _$PromptPartFilePathFromJson(Map json) => PromptPartFilePath(
  mime: json['mime'] as String,
  path: json['path'] as String,
  filename: json['filename'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$PromptPartFilePathToJson(PromptPartFilePath instance) =>
    <String, dynamic>{
      'mime': instance.mime,
      'path': instance.path,
      'filename': instance.filename,
      'type': instance.$type,
    };

PromptPartFileUrl _$PromptPartFileUrlFromJson(Map json) => PromptPartFileUrl(
  mime: json['mime'] as String,
  url: json['url'] as String,
  filename: json['filename'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$PromptPartFileUrlToJson(PromptPartFileUrl instance) =>
    <String, dynamic>{
      'mime': instance.mime,
      'url': instance.url,
      'filename': instance.filename,
      'type': instance.$type,
    };

PromptPartFileData _$PromptPartFileDataFromJson(Map json) => PromptPartFileData(
  mime: json['mime'] as String,
  base64: json['base64'] as String,
  filename: json['filename'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$PromptPartFileDataToJson(PromptPartFileData instance) =>
    <String, dynamic>{
      'mime': instance.mime,
      'base64': instance.base64,
      'filename': instance.filename,
      'type': instance.$type,
    };

_PromptModel _$PromptModelFromJson(Map json) => _PromptModel(
  providerID: json['providerID'] as String,
  modelID: json['modelID'] as String,
);

Map<String, dynamic> _$PromptModelToJson(_PromptModel instance) =>
    <String, dynamic>{
      'providerID': instance.providerID,
      'modelID': instance.modelID,
    };
