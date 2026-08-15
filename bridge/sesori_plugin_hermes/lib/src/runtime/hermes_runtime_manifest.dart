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

  /// Extracts the first whitespace-separated semantic version token from
  /// `hermes acp --version` output, tolerating an optional `v` prefix.
  static SemanticVersion? tryParseVersion({required String value}) {
    for (final rawToken in value.split(RegExp(r"\s+"))) {
      final token = rawToken.trim();
      final candidate = (token.startsWith("v") || token.startsWith("V")) ? token.substring(1) : token;
      final version = SemanticVersion.tryParse(value: candidate);
      if (version != null) return version;
    }
    return null;
  }
}
