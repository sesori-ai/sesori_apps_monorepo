import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "api/codex_rollout_api.dart" show resolveCodexHome;

/// Top-level defaults read from `~/.codex/config.toml`.
///
/// Codex has no agent/provider HTTP API, so the global config is the
/// fallback source for the configured model and provider when a session's
/// own rollout records don't carry them. Per-session rollout data always
/// takes precedence over these defaults.
class CodexConfigDefaults {
  const new({required this.model, required this.modelProvider});

  const new empty() : model = null, modelProvider = null;

  /// Codex's built-in provider, used when `config.toml` names none.
  static const String builtInModelProvider = "openai";

  final String? model;
  final String? modelProvider;

  String get effectiveModelProvider => modelProvider ?? builtInModelProvider;
}

/// Reads the top-level `model` and `model_provider` keys from
/// `~/.codex/config.toml`.
///
/// The file lives under [resolveCodexHome].
///
/// Intentionally minimal: only top-level assignments (above any `[section]`)
/// are read. Profile-scoped model overrides (`[profiles.*]`) are not resolved
/// — rollouts are the authoritative per-session source, and this is only a
/// fallback for sessions that predate `turn_context` records.
// COMPATIBILITY 2026-11-03 (v1.12.0): Codex rollouts may omit `turn_context`
// model metadata. Keep this live backend fallback unless Codex guarantees that
// metadata for every rollout.
class CodexConfigReader({required final Map<String, String> _environment}) {
  CodexConfigDefaults readDefaults() {
    final home = resolveCodexHome(environment: _environment);
    if (home == null) return const CodexConfigDefaults.empty();

    final file = File(p.join(home, "config.toml"));
    if (!file.existsSync()) return const CodexConfigDefaults.empty();

    final List<String> rawLines;
    try {
      rawLines = file.readAsLinesSync();
    } on Object catch (error, stackTrace) {
      Log.w("[codex] failed to read fallback config defaults from ${file.path}", error, stackTrace);
      return const CodexConfigDefaults.empty();
    }

    String? model;
    String? modelProvider;
    for (final rawLine in rawLines) {
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
    return _normalize(raw: line.substring(eq + 1).trim());
  }

  static String? _normalize({required String raw}) {
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
