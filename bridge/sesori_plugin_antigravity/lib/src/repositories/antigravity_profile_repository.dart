import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../foundation/antigravity_authentication_budget.dart";
import "../models/antigravity_profile.dart";
import "../storage/antigravity_profile_storage.dart";
import "../storage/models/antigravity_profile_settings_dto.dart";

class AntigravityProfileRepository({required final AntigravityProfileStorage _storage}) {
  String get geminiHome => _storage.geminiHome;

  bool hasToken() => _storage.tokenExists();

  Future<void> preparePersonalOauth({required AntigravityAuthenticationBudget budget}) async {
    try {
      await _storage.prepareDirectories(budget: budget);
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

  Future<bool> verifyBrowserCommand({
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
      return result.exitCode == 0 && result.stdout.isEmpty && result.stderr.isEmpty;
    } on TimeoutException {
      rethrow;
    } on PluginStartAbortedException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AntigravityProfileException(message: "Browser suppression preflight failed", cause: error),
        stackTrace,
      );
    }
  }
}
