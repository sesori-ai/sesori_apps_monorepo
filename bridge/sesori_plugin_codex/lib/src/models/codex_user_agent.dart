import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show SemanticVersion;

/// Whether the app-server's `initialize` [userAgent], such as
/// `codex-cli/0.169.0 (Mac OS 15.0; arm64)`, names Codex [minimum] or newer.
/// False when it names no version.
bool codexUserAgentIsAtLeast({required String? userAgent, required String minimum}) {
  if (userAgent == null) return false;
  final value = RegExp(r"^[^/]+/([^\s]+)").firstMatch(userAgent)?.group(1);
  final version = value == null ? null : SemanticVersion.tryParse(value: value);
  return version != null && version.compareTo(SemanticVersion.parse(value: minimum)) >= 0;
}
