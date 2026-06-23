import 'package:sesori_plugin_runtime/sesori_plugin_runtime.dart';

import 'release_info.dart';

/// A snapshot for deciding an explicit update.
///
/// Carries the running version, whether it is eligible for the active release
/// track, and the latest eligible release (if any) with its typed version.
/// Version parsing/typing lives in the repository that builds this; consumers
/// only compare the already-typed values.
class UpdateResolution {
  /// The version of the currently running binary.
  final SemanticVersion currentVersion;

  /// Whether [currentVersion] is eligible for the active track (e.g. an
  /// `-internal.*` build is not eligible while the track is `stable`).
  final bool currentEligible;

  /// The latest release eligible for the active track, or `null` when none was
  /// found (empty/unreachable release set is surfaced as an error upstream).
  final ReleaseInfo? latestEligible;

  /// The typed version of [latestEligible], or `null` when there is none.
  final SemanticVersion? latestVersion;

  const UpdateResolution({
    required this.currentVersion,
    required this.currentEligible,
    required this.latestEligible,
    required this.latestVersion,
  });
}
