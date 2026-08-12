// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_attachment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SessionAttachmentRequest _$SessionAttachmentRequestFromJson(Map json) =>
    _SessionAttachmentRequest(
      sessionId: json['sessionId'] as String,
      attachmentId: json['attachmentId'] as String,
      rendition: $enumDecode(
        _$SessionAttachmentRenditionEnumMap,
        json['rendition'],
      ),
    );

Map<String, dynamic> _$SessionAttachmentRequestToJson(
  _SessionAttachmentRequest instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'attachmentId': instance.attachmentId,
  'rendition': _$SessionAttachmentRenditionEnumMap[instance.rendition]!,
};

const _$SessionAttachmentRenditionEnumMap = {
  SessionAttachmentRendition.thumbnail: 'thumbnail',
  SessionAttachmentRendition.original: 'original',
};

_SessionAttachmentResponse _$SessionAttachmentResponseFromJson(Map json) =>
    _SessionAttachmentResponse(
      mime: json['mime'] as String,
      base64: json['base64'] as String,
      byteLength: (json['byteLength'] as num).toInt(),
    );

Map<String, dynamic> _$SessionAttachmentResponseToJson(
  _SessionAttachmentResponse instance,
) => <String, dynamic>{
  'mime': instance.mime,
  'base64': instance.base64,
  'byteLength': instance.byteLength,
};
