// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cached_release.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CachedRelease _$CachedReleaseFromJson(Map json) => _CachedRelease(
  latestVersion: json['latestVersion'] as String,
  downloadUrl: json['downloadUrl'] as String,
  checksumsUrl: json['checksumsUrl'] as String,
  assetName: json['assetName'] as String,
  publishedAt: DateTime.parse(json['publishedAt'] as String),
  checkedAt: DateTime.parse(json['checkedAt'] as String),
);

Map<String, dynamic> _$CachedReleaseToJson(_CachedRelease instance) =>
    <String, dynamic>{
      'latestVersion': instance.latestVersion,
      'downloadUrl': instance.downloadUrl,
      'checksumsUrl': instance.checksumsUrl,
      'assetName': instance.assetName,
      'publishedAt': instance.publishedAt.toIso8601String(),
      'checkedAt': instance.checkedAt.toIso8601String(),
    };
