import 'package:freezed_annotation/freezed_annotation.dart';

part 'release_info.freezed.dart';
part 'release_info.g.dart';

/// A newer release available for download.
@Freezed(fromJson: true, toJson: true)
sealed class ReleaseInfo with _$ReleaseInfo {
  const factory ReleaseInfo({
    /// The version string of the release (e.g., "0.3.0").
    required String version,

    /// The download URL for the platform-specific asset.
    required String assetUrl,

    /// The URL to the checksums file for verification.
    required String checksumsUrl,

    /// When this release was published on GitHub.
    required DateTime publishedAt,
  }) = _ReleaseInfo;

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) => _$ReleaseInfoFromJson(json);
}
