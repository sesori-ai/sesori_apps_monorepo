// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'github_release_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GitHubReleaseDto _$GitHubReleaseDtoFromJson(Map json) => _GitHubReleaseDto(
  tagName: json['tag_name'] as String,
  publishedAt: json['published_at'] as String?,
  draft: json['draft'] as bool,
  prerelease: json['prerelease'] as bool,
  assets: (json['assets'] as List<dynamic>)
      .map((e) => GitHubAssetDto.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
);

_GitHubAssetDto _$GitHubAssetDtoFromJson(Map json) => _GitHubAssetDto(
  name: json['name'] as String,
  browserDownloadUrl: json['browser_download_url'] as String,
);
