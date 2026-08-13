import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";

/// Pinned facts about the Hermes ACP adapter the bridge gates on.
///
/// Hermes has no Sesori-managed runtime: it installs itself via its own
/// installer and the bridge resolves it on PATH (or via `--hermes-bin`). This
/// manifest only pins the minimum adapter version and the version parsing.
///
/// Note the version identity: `hermes acp --version` reports the ACP adapter's
/// own version (e.g. `0.20.0`), not the Hermes release version. The probe
/// gates on the adapter version, which is the surface the bridge talks to.
abstract final class HermesRuntimeManifest() {
  /// Minimum ACP adapter version the bridge uses as-is. Older adapters either
  /// predate the `hermes acp` surface entirely or lack behavior the base ACP
  /// machinery relies on.
  static final SemanticVersion minAcpVersion = SemanticVersion.parse(value: "0.20.0");

  /// Parses the bare version `hermes acp --version` prints (`0.20.0`),
  /// tolerating an optional leading `v` defensively. Returns null when the
  /// output is not a recognizable semver.
  static SemanticVersion? tryParseVersion({required String value}) {
    final trimmed = value.trim();
    final withoutPrefix = trimmed.startsWith("v") ? trimmed.substring(1) : trimmed;
    return SemanticVersion.tryParse(value: withoutPrefix);
  }
}
