import 'package:freezed_annotation/freezed_annotation.dart';

part 'cached_release.freezed.dart';
part 'cached_release.g.dart';

/// Cached release information with TTL support.
@Freezed(fromJson: true, toJson: true)
sealed class CachedRelease with _$CachedRelease {
  const factory CachedRelease({
    /// The latest version string found during the check.
    required String latestVersion,

    /// The download URL for the latest release.
    required String downloadUrl,

    /// The URL to the checksums file for verification.
    required String checksumsUrl,

    /// The release asset name this cache entry was resolved for.
    required String assetName,

    /// When this release was published upstream.
    required DateTime publishedAt,

    /// When this cache entry was created.
    required DateTime checkedAt,
  }) = _CachedRelease;

  factory CachedRelease.fromJson(Map<String, dynamic> json) => _$CachedReleaseFromJson(json);
}
