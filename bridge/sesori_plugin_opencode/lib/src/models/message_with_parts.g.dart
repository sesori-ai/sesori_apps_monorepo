// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_with_parts.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MessageWithParts _$MessageWithPartsFromJson(Map json) => _MessageWithParts(
  info: Message.fromJson(Map<String, dynamic>.from(json['info'] as Map)),
  parts: (json['parts'] as List<dynamic>)
      .map((e) => MessagePart.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
);

Map<String, dynamic> _$MessageWithPartsToJson(_MessageWithParts instance) =>
    <String, dynamic>{
      'info': instance.info.toJson(),
      'parts': instance.parts.map((e) => e.toJson()).toList(),
    };
