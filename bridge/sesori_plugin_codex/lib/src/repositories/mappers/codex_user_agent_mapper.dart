import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show SemanticVersion;

/// Maps the app-server's `initialize` userAgent to the Codex version it
/// names.
class const CodexUserAgentMapper() {
  /// 0.169.0 for `codex-cli/0.169.0 (Mac OS 15.0; arm64)`; null when
  /// [userAgent] names no version.
  SemanticVersion? codexVersion({required String? userAgent}) {
    final version = userAgent == null ? null : RegExp(r"^[^/]+/([^\s]+)").firstMatch(userAgent)?.group(1);
    return version == null ? null : SemanticVersion.tryParse(value: version);
  }
}
