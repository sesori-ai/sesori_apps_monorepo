import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "../foundation/claude_config_directory.dart";
import "../foundation/trimmed_or_null.dart";

/// Layer-1 reader for the Claude Code configuration that decides where the
/// CLI sends its requests. It never reads or logs credential values.
class ClaudeSettingsApi({required Map<String, String> environment}) {
  static const String _baseUrlVariable = "ANTHROPIC_BASE_URL";
  static const String _defaultBaseUrl = "https://api.anthropic.com";

  final Map<String, String> _environment = Map.unmodifiable(environment);

  /// Whether Claude Code sends requests to a base URL other than Anthropic's,
  /// such as a gateway that owns authentication.
  ///
  /// Follows the CLI's precedence: an `env.ANTHROPIC_BASE_URL` in the user
  /// settings file, even an empty one, overrides the process environment.
  bool usesCustomBaseUrl() {
    final configured = _settingsBaseUrl() ?? _environment[_baseUrlVariable];
    final baseUrl = trimmedOrNull(value: configured)?.replaceFirst(RegExp(r"/+$"), "");
    return baseUrl != null && baseUrl != _defaultBaseUrl;
  }

  /// `env.ANTHROPIC_BASE_URL` from `<config dir>/settings.json`, or null when
  /// the file or the key is absent or unreadable.
  String? _settingsBaseUrl() {
    final configDirectory = claudeConfigDirectory(environment: _environment);
    if (configDirectory == null) return null;
    final settingsPath = p.join(configDirectory, "settings.json");
    try {
      final settings = jsonDecodeMap(File(settingsPath).readAsStringSync());
      return switch (settings["env"]) {
        {_baseUrlVariable: final String value} => value,
        _ => null,
      };
    } on PathNotFoundException {
      return null;
    } on Object catch (error) {
      // The error is not logged: a parse error quotes the file, which can hold tokens.
      Log.w("[claude] ignored unreadable settings at '$settingsPath' (${error.runtimeType})");
      return null;
    }
  }
}
