import 'package:freezed_annotation/freezed_annotation.dart';

part 'release_info.freezed.dart';

/// A newer release available for download.
@freezed
sealed class ReleaseInfo with _$ReleaseInfo {
  const factory({
    /// The version string of the release (e.g., "0.3.0").
    required String version,

    /// The download URL for the platform-specific asset.
    required String assetUrl,

    /// The URL to the checksums file for verification.
    required String checksumsUrl,
  }) = _ReleaseInfo;
}
