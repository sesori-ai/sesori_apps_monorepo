// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'release_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ReleaseInfo _$ReleaseInfoFromJson(Map json) => _ReleaseInfo(
  version: json['version'] as String,
  assetUrl: json['assetUrl'] as String,
  checksumsUrl: json['checksumsUrl'] as String,
  publishedAt: DateTime.parse(json['publishedAt'] as String),
);

Map<String, dynamic> _$ReleaseInfoToJson(_ReleaseInfo instance) =>
    <String, dynamic>{
      'version': instance.version,
      'assetUrl': instance.assetUrl,
      'checksumsUrl': instance.checksumsUrl,
      'publishedAt': instance.publishedAt.toIso8601String(),
    };
