import "dart:convert";
import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../foundation/antigravity_authentication_budget.dart";
import "models/antigravity_profile_settings_dto.dart";

/// File/process boundary. The injected store must be the live host root's
/// profile/antigravity-acp scope, not an independently constructed store.
/// Composition must configure the injected host command executor with
/// includeParentEnvironment: false for preflight and directory preparation.
class AntigravityProfileStorage({
  required final String geminiHome,
  required final HostJsonStore _settingsStore,
  required final CommandExecutor _commands,
  required final PlatformTarget _target,
}) {
  String get acpDirectory => p.join(geminiHome, "antigravity-acp");

  Future<void> prepareDirectories({
    required AntigravityAuthenticationBudget budget,
    required Map<String, String> environment,
  }) async {
    for (final directory in [geminiHome, acpDirectory]) {
      budget.remaining;
      await Directory(directory).create(recursive: true);
      budget.remaining;
      if (_target.os != PlatformOs.windows) {
        final result = await _commands.run(
          "chmod",
          ["700", directory],
          environment: environment,
          timeout: budget.remaining,
        );
        budget.remaining;
        if (result.exitCode != 0) {
          throw FileSystemException("Cannot make Antigravity profile private: ${result.stderr}", directory);
        }
      }
    }
  }

  Future<void> writeSettings({required AntigravityProfileSettingsDto settings}) =>
      _settingsStore.write(name: "settings.json", contents: "${jsonEncode(settings.toJson())}\n");

  Future<CommandResult> runBrowserPreflight({
    required AntigravityAuthenticationBudget budget,
    required String executable,
    required List<String> arguments,
    required Map<String, String> environment,
  }) {
    // Source-mode helpers compile the bridge before reaching the silent no-op.
    // Keep them within the operation deadline, not a native-startup-sized cap.
    return _commands.run(
      executable,
      arguments,
      environment: environment,
      timeout: budget.remaining,
    );
  }
}
