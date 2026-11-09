import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "../foundation/claude_config_directory.dart";

/// Layer-1 reader for Claude Code's user settings file. It reads only the
/// values Sesori acts on and never credential values.
class ClaudeSettingsApi({required Map<String, String> environment}) {
  static const String baseUrlVariable = "ANTHROPIC_BASE_URL";

  final Map<String, String> _environment = Map.unmodifiable(environment);

  /// `<config dir>/settings.json`, or null when no config directory resolves.
  String? get userSettingsPath {
    final configDirectory = claudeConfigDirectory(environment: _environment);
    return configDirectory == null ? null : p.join(configDirectory, "settings.json");
  }

  /// `env.ANTHROPIC_BASE_URL` from the user settings file, or null when the
  /// file or the key is absent. Throws when the file cannot be read or parsed.
  String? readBaseUrl() {
    final settingsPath = userSettingsPath;
    if (settingsPath == null) return null;
    final String source;
    try {
      source = File(settingsPath).readAsStringSync();
    } on PathNotFoundException {
      return null;
    }
    return switch (jsonDecodeMap(source)["env"]) {
      {baseUrlVariable: final String value} => value,
      _ => null,
    };
  }
}
