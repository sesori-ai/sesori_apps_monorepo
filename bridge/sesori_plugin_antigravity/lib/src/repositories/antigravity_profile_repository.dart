import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../foundation/antigravity_authentication_budget.dart";
import "../models/antigravity_profile.dart";
import "../storage/antigravity_profile_storage.dart";
import "../storage/models/antigravity_profile_settings_dto.dart";

class AntigravityProfileRepository({required final AntigravityProfileStorage _storage}) {
  String get geminiHome => _storage.geminiHome;

  Future<void> preparePersonalOauth({
    required AntigravityAuthenticationBudget budget,
    required Map<String, String> environment,
  }) async {
    try {
      await _storage.prepareDirectories(budget: budget, environment: environment);
      budget.remaining;
      await _storage.writeSettings(
        settings: const AntigravityProfileSettingsDto(
          auth: AntigravityProfileAuthDto(type: AntigravityProfileAuthType.personalOauth),
        ),
      );
      budget.remaining;
    } on TimeoutException {
      rethrow;
    } on PluginStartAbortedException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AntigravityProfileException(message: "Cannot prepare private profile at $geminiHome", cause: error),
        stackTrace,
      );
    }
  }

  Future<AntigravityBrowserPreflightResult> inspectBrowserCommand({
    required AntigravityAuthenticationBudget budget,
    required String executable,
    required List<String> arguments,
    required Map<String, String> environment,
  }) async {
    try {
      final result = await _storage.runBrowserPreflight(
        budget: budget,
        executable: executable,
        arguments: arguments,
        environment: environment,
      );
      budget.remaining;
      return AntigravityBrowserPreflightResult(
        exitCode: result.exitCode,
        hasOutput: result.stdout.isNotEmpty || result.stderr.isNotEmpty,
        diagnostics: result,
      );
    } on TimeoutException {
      rethrow;
    } on PluginStartAbortedException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AntigravityProfileException(message: "Browser suppression preflight failed for $executable", cause: error),
        stackTrace,
      );
    }
  }
}
