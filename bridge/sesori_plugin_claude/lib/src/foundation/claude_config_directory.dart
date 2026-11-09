import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show resolveUserHomeDirectory;

/// Claude Code's config directory: `$CLAUDE_CONFIG_DIR`, else `<home>/.claude`.
/// Null when no home resolves.
String? claudeConfigDirectory({required Map<String, String> environment}) {
  final explicit = environment["CLAUDE_CONFIG_DIR"];
  if (explicit != null && explicit.isNotEmpty) return explicit;
  final home = resolveUserHomeDirectory(environment: environment);
  if (home == null) return null;
  return p.join(home, ".claude");
}
