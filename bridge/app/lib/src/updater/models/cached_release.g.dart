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
  track:
      $enumDecodeNullable(_$ReleaseTrackEnumMap, json['track']) ??
      ReleaseTrack.stable,
  checkedAt: DateTime.parse(json['checkedAt'] as String),
);

Map<String, dynamic> _$CachedReleaseToJson(_CachedRelease instance) =>
    <String, dynamic>{
      'latestVersion': instance.latestVersion,
      'downloadUrl': instance.downloadUrl,
      'checksumsUrl': instance.checksumsUrl,
      'assetName': instance.assetName,
      'track': _$ReleaseTrackEnumMap[instance.track]!,
      'checkedAt': instance.checkedAt.toIso8601String(),
    };

const _$ReleaseTrackEnumMap = {
  ReleaseTrack.stable: 'stable',
  ReleaseTrack.internal: 'internal',
};
