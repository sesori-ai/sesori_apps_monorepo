import "../models/antigravity_profile.dart";
import "../storage/antigravity_profile_storage.dart";
import "../storage/models/antigravity_profile_settings_dto.dart";

class AntigravityProfileRepository({required final AntigravityProfileStorage _storage}) {
  String get geminiHome => _storage.geminiHome;

  bool hasToken() => _storage.tokenExists();

  Future<void> preparePersonalOauth({required Map<String, String> environment}) async {
    try {
      await _storage.prepareDirectories(environment: environment);
      await _storage.writeSettings(
        settings: const AntigravityProfileSettingsDto(
          auth: AntigravityProfileAuthDto(type: AntigravityProfileAuthType.personalOauth),
        ),
      );
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AntigravityProfileException(message: "Cannot prepare private profile at $geminiHome", cause: error),
        stackTrace,
      );
    }
  }

  Future<AntigravityBrowserPreflightResult> inspectBrowserCommand({
    required String executable,
    required List<String> arguments,
    required Map<String, String> environment,
  }) async {
    try {
      final result = await _storage.runBrowserPreflight(
        executable: executable,
        arguments: arguments,
        environment: environment,
      );
      return AntigravityBrowserPreflightResult(
        exitCode: result.exitCode,
        hasOutput: result.stdout.isNotEmpty || result.stderr.isNotEmpty,
        diagnostics: result,
      );
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AntigravityProfileException(message: "Browser suppression preflight failed for $executable", cause: error),
        stackTrace,
      );
    }
  }
}
