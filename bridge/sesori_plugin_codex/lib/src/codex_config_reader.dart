import "dart:io";

import "package:path/path.dart" as p;

/// Top-level defaults read from `~/.codex/config.toml`.
///
/// Codex has no agent/provider HTTP API, so the global config is the
/// fallback source for the configured model and provider when a session's
/// own rollout records don't carry them. Per-session rollout data always
/// takes precedence over these defaults.
class CodexConfigDefaults {
  const CodexConfigDefaults({required this.model, required this.modelProvider});

  const CodexConfigDefaults.empty() : model = null, modelProvider = null;

  final String? model;
  final String? modelProvider;
}

/// Reads the top-level `model` and `model_provider` keys from
/// `~/.codex/config.toml`.
///
/// CODEX_HOME resolution mirrors codex itself (and [SessionRolloutReader]):
///   1. `$CODEX_HOME` if set.
///   2. `$HOME/.codex` (or `$USERPROFILE\.codex` on Windows).
///
/// Intentionally minimal: only top-level assignments (above any `[section]`)
/// are read. Profile-scoped model overrides (`[profiles.*]`) are not resolved
/// — rollouts are the authoritative per-session source, and this is only a
/// fallback for sessions that predate `turn_context` records.
class CodexConfigReader {
  CodexConfigReader({Map<String, String>? environment})
    : _environment = environment ?? Platform.environment;

  final Map<String, String> _environment;

  String? get _codexHome {
    final explicit = _environment["CODEX_HOME"];
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final home = _environment["HOME"] ?? _environment["USERPROFILE"];
    if (home == null || home.isEmpty) return null;
    return p.join(home, ".codex");
  }

  CodexConfigDefaults readDefaults() {
    final home = _codexHome;
    if (home == null) return const CodexConfigDefaults.empty();

    final file = File(p.join(home, "config.toml"));
    if (!file.existsSync()) return const CodexConfigDefaults.empty();

    String? model;
    String? modelProvider;
    for (final rawLine in file.readAsLinesSync()) {
      final line = rawLine.split("#").first.trim();
      if (line.isEmpty) continue;
      // Stop at the first table header — the keys we care about are
      // top-level and appear above any section.
      if (line.startsWith("[")) break;

      model ??= _parseStringAssignment(line: line, key: "model");
      modelProvider ??= _parseStringAssignment(line: line, key: "model_provider");
      if (model != null && modelProvider != null) break;
    }

    return CodexConfigDefaults(model: model, modelProvider: modelProvider);
  }

  static String? _parseStringAssignment({
    required String line,
    required String key,
  }) {
    if (!line.startsWith("$key ") && !line.startsWith("$key=")) return null;
    final eq = line.indexOf("=");
    if (eq < 0 || line.substring(0, eq).trim() != key) return null;
    return _normalize(line.substring(eq + 1).trim());
  }

  static String? _normalize(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length >= 2) {
      final first = trimmed[0];
      final last = trimmed[trimmed.length - 1];
      if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
        final unquoted = trimmed.substring(1, trimmed.length - 1).trim();
        return unquoted.isEmpty ? null : unquoted;
      }
    }
    return trimmed;
  }
}
