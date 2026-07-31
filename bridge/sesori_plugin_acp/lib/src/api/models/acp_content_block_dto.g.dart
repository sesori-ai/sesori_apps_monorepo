// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'acp_content_block_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AcpTextContentBlockDto _$AcpTextContentBlockDtoFromJson(Map json) =>
    AcpTextContentBlockDto(
      text: json['text'] as String,
      $type: json['type'] as String?,
    );

AcpImageContentBlockDto _$AcpImageContentBlockDtoFromJson(Map json) =>
    AcpImageContentBlockDto(
      data: json['data'] as String,
      mimeType: json['mimeType'] as String,
      uri: json['uri'] as String?,
      $type: json['type'] as String?,
    );

AcpUnsupportedAudioContentBlockDto _$AcpUnsupportedAudioContentBlockDtoFromJson(
  Map json,
) => AcpUnsupportedAudioContentBlockDto($type: json['type'] as String?);

AcpUnsupportedResourceContentBlockDto
_$AcpUnsupportedResourceContentBlockDtoFromJson(Map json) =>
    AcpUnsupportedResourceContentBlockDto($type: json['type'] as String?);

AcpUnsupportedResourceLinkContentBlockDto
_$AcpUnsupportedResourceLinkContentBlockDtoFromJson(Map json) =>
    AcpUnsupportedResourceLinkContentBlockDto($type: json['type'] as String?);

AcpUnknownContentBlockDto _$AcpUnknownContentBlockDtoFromJson(Map json) =>
    AcpUnknownContentBlockDto($type: json['type'] as String?);
