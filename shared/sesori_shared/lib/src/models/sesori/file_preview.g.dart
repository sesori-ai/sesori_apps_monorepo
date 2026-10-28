// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_preview.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FilePreviewRequest _$FilePreviewRequestFromJson(Map json) =>
    _FilePreviewRequest(path: json['path'] as String);

Map<String, dynamic> _$FilePreviewRequestToJson(_FilePreviewRequest instance) =>
    <String, dynamic>{'path': instance.path};

FilePreviewText _$FilePreviewTextFromJson(Map json) => FilePreviewText(
  content: json['content'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$FilePreviewTextToJson(FilePreviewText instance) =>
    <String, dynamic>{'content': instance.content, 'type': instance.$type};

FilePreviewImage _$FilePreviewImageFromJson(Map json) => FilePreviewImage(
  mime: json['mime'] as String,
  base64: json['base64'] as String,
  byteLength: (json['byteLength'] as num).toInt(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$FilePreviewImageToJson(FilePreviewImage instance) =>
    <String, dynamic>{
      'mime': instance.mime,
      'base64': instance.base64,
      'byteLength': instance.byteLength,
      'type': instance.$type,
    };

FilePreviewMissing _$FilePreviewMissingFromJson(Map json) =>
    FilePreviewMissing($type: json['type'] as String?);

Map<String, dynamic> _$FilePreviewMissingToJson(FilePreviewMissing instance) =>
    <String, dynamic>{'type': instance.$type};

FilePreviewTooLarge _$FilePreviewTooLargeFromJson(Map json) =>
    FilePreviewTooLarge($type: json['type'] as String?);

Map<String, dynamic> _$FilePreviewTooLargeToJson(
  FilePreviewTooLarge instance,
) => <String, dynamic>{'type': instance.$type};

FilePreviewUnsupported _$FilePreviewUnsupportedFromJson(Map json) =>
    FilePreviewUnsupported($type: json['type'] as String?);

Map<String, dynamic> _$FilePreviewUnsupportedToJson(
  FilePreviewUnsupported instance,
) => <String, dynamic>{'type': instance.$type};

FilePreviewDenied _$FilePreviewDeniedFromJson(Map json) =>
    FilePreviewDenied($type: json['type'] as String?);

Map<String, dynamic> _$FilePreviewDeniedToJson(FilePreviewDenied instance) =>
    <String, dynamic>{'type': instance.$type};
