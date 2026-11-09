import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../api/claude_settings_api.dart";
import "../foundation/trimmed_or_null.dart";

/// Decides whether Claude Code sends its requests somewhere other than
/// Anthropic, such as a gateway that owns authentication.
class ClaudeBaseUrlRepository({
  required final ClaudeSettingsApi _settings,
  required Map<String, String> environment,
}) {
  static const String _defaultBaseUrl = "https://api.anthropic.com";

  final String? _environmentBaseUrl = environment[ClaudeSettingsApi.baseUrlVariable];

  /// Follows the CLI's precedence: an `env.ANTHROPIC_BASE_URL` in the user
  /// settings file, even an empty one, overrides the process environment. An
  /// unreadable or malformed settings file is ignored, as the CLI ignores it.
  bool usesCustomBaseUrl() {
    final configured = _settingsBaseUrl() ?? _environmentBaseUrl;
    final baseUrl = trimmedOrNull(value: configured)?.replaceFirst(RegExp(r"/+$"), "");
    return baseUrl != null && baseUrl.toLowerCase() != _defaultBaseUrl;
  }

  String? _settingsBaseUrl() {
    try {
      return _settings.readBaseUrl();
    } on FileSystemException catch (error, stackTrace) {
      Log.w("[claude] ignored unreadable Claude settings; using the environment base URL", error, stackTrace);
      return null;
    } on Object catch (error, stackTrace) {
      // Only the type is logged: a parse error quotes the file, which can hold tokens.
      Log.w(
        "[claude] ignored malformed Claude settings at '${_settings.userSettingsPath}' "
        "(${error.runtimeType}); using the environment base URL",
        null,
        stackTrace,
      );
      return null;
    }
  }
}
