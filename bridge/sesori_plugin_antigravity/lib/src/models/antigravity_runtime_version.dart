import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";

import "../foundation/antigravity_release.dart";
import "antigravity_runtime_resolution.dart";

sealed class const AntigravityRuntimeVersion({required final String buildLabel})
    implements Comparable<AntigravityRuntimeVersion> {
  static final _legacyPattern = RegExp(r"^(\d{8})_(\d{2})_RC(\d{2})$");

  static AntigravityRuntimeVersion? tryParse({required String buildLabel}) {
    final hasPrefix = buildLabel.startsWith(AntigravityRelease.serverBuildLabelPrefix);
    final value = hasPrefix ? buildLabel.substring(AntigravityRelease.serverBuildLabelPrefix.length) : buildLabel;
    final semantic = SemanticVersion.tryParse(value: value);
    if (semantic != null) {
      return _AntigravitySemanticRuntimeVersion(buildLabel: buildLabel, version: semantic);
    }
    if (!hasPrefix) return null;
    final legacy = _legacyPattern.firstMatch(value);
    if (legacy == null) return null;
    final releaseDate = int.tryParse(legacy.group(1) ?? "");
    final sequence = int.tryParse(legacy.group(2) ?? "");
    final releaseCandidate = int.tryParse(legacy.group(3) ?? "");
    if (releaseDate == null || sequence == null || releaseCandidate == null) return null;
    return _AntigravityLegacyRuntimeVersion(
      buildLabel: buildLabel,
      releaseDate: releaseDate,
      sequence: sequence,
      releaseCandidate: releaseCandidate,
    );
  }
}

final class const _AntigravitySemanticRuntimeVersion({
  required super.buildLabel,
  required final SemanticVersion version,
}) extends AntigravityRuntimeVersion {
  @override
  int compareTo(AntigravityRuntimeVersion other) => switch (other) {
    _AntigravitySemanticRuntimeVersion(:final version) => this.version.compareTo(version),
    _AntigravityLegacyRuntimeVersion() => 1,
  };
}

final class const _AntigravityLegacyRuntimeVersion({
  required super.buildLabel,
  required final int releaseDate,
  required final int sequence,
  required final int releaseCandidate,
}) extends AntigravityRuntimeVersion {
  @override
  int compareTo(AntigravityRuntimeVersion other) => switch (other) {
    _AntigravitySemanticRuntimeVersion() => -1,
    _AntigravityLegacyRuntimeVersion(
      :final releaseDate,
      :final sequence,
      :final releaseCandidate,
    ) =>
      switch (this.releaseDate.compareTo(releaseDate)) {
        final comparison when comparison != 0 => comparison,
        _ => switch (this.sequence.compareTo(sequence)) {
          final comparison when comparison != 0 => comparison,
          _ => this.releaseCandidate.compareTo(releaseCandidate),
        },
      },
  };
}

sealed class const AntigravityRuntimeVersionProbeResult();

final class const AntigravityRuntimeVersionProbeSucceeded({
  required final AntigravityRuntimeSource source,
  required final AntigravityRuntimeVersion version,
}) extends AntigravityRuntimeVersionProbeResult;

final class const AntigravityRuntimeVersionProbeRejected({
  required final AntigravityRuntimeSource source,
  required final int exitCode,
}) extends AntigravityRuntimeVersionProbeResult;

final class const AntigravityRuntimeVersionProbeFailed({
  required final AntigravityRuntimeSource source,
  // ignore: no_slop_linter/prefer_specific_type, Dart permits thrown values with no narrower sound shared type
  required final Object cause,
  required final StackTrace stackTrace,
}) extends AntigravityRuntimeVersionProbeResult;
