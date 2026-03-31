import 'package:freezed_annotation/freezed_annotation.dart';

part 'github_release_dto.freezed.dart';
part 'github_release_dto.g.dart';

@Freezed(fromJson: true, toJson: false)
sealed class GitHubReleaseDto with _$GitHubReleaseDto {
  const factory GitHubReleaseDto({
    @JsonKey(name: 'tag_name') required String tagName,
    @JsonKey(name: 'published_at') required String publishedAt,
    required bool draft,
    required bool prerelease,
    required List<GitHubAssetDto> assets,
  }) = _GitHubReleaseDto;

  factory GitHubReleaseDto.fromJson(Map<String, dynamic> json) => _$GitHubReleaseDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class GitHubAssetDto with _$GitHubAssetDto {
  const factory GitHubAssetDto({
    required String name,
    @JsonKey(name: 'browser_download_url') required String browserDownloadUrl,
  }) = _GitHubAssetDto;

  factory GitHubAssetDto.fromJson(Map<String, dynamic> json) => _$GitHubAssetDtoFromJson(json);
}
