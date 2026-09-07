import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";

import "../foundation/antigravity_authentication_budget.dart";
import "../models/antigravity_profile.dart";
import "../repositories/antigravity_profile_repository.dart";

/// Owns personal-auth profile policy; no ambient environment or credentials are read.
class AntigravityProfileService({
  required final AntigravityProfileRepository _repository,
  required final PlatformTarget _target,
  required final String _browserExecutable,
  required List<String> browserPrefixArguments,
}) {
  final List<String> _browserPrefixArguments = List.unmodifiable(browserPrefixArguments);
  static const browserPreflightUrl = "https://example.invalid/sesori-browser-preflight";
  static const _removedPrefixes = ["GOOGLE_", "GEMINI_", "GCLOUD_", "CLOUDSDK_", "AGY_", "ANTIGRAVITY_", "PYTHON"];
  static const _removedKeys = {"BROWSER", "ELECTRON_RUN_AS_NODE", "GCP_PROJECT", "GCP_LOCATION"};

  AntigravityAuthenticationHint inspectAuthentication() => _repository.hasToken()
      ? AntigravityAuthenticationHint.tokenPresent
      : AntigravityAuthenticationHint.authenticationRequired;

  Future<AntigravityPreparedProfile> prepare({
    required Map<String, String> hostEnvironment,
    required AntigravityAuthenticationBudget budget,
  }) async {
    budget.remaining;
    final invocation = [_browserExecutable, ..._browserPrefixArguments, BrowserNoop.argument];
    final separator = _target.os == PlatformOs.windows ? ";" : ":";
    // Python splits BROWSER before shlex parsing, even inside quotes. A failed
    // helper would fall through to the real OS browser, so reject before launch.
    if (invocation.any(
      (argument) =>
          argument.isEmpty ||
          argument.contains(separator) ||
          argument.contains("%s") ||
          RegExp(r"[\x00-\x1f\x7f]").hasMatch(argument),
    )) {
      throw const AntigravityProfileException(
        message: "Bridge invocation cannot suppress browser launches",
        cause: null,
      );
    }
    final command = [...invocation.map((argument) => _quote(argument: argument)), "'%s'"].join(" ");
    final environment = <String, String>{
      for (final entry in hostEnvironment.entries)
        if (!_removedKeys.contains(entry.key.toUpperCase()) &&
            !_removedPrefixes.any(entry.key.toUpperCase().startsWith))
          entry.key: entry.value,
      "GEMINI_HOME": _repository.geminiHome,
      "AGY_ACP_FORCE_FILE_STORAGE": "1",
      "BROWSER": command,
      "PYTHONUNBUFFERED": "1",
    };
    if (!await _repository.verifyBrowserCommand(
      budget: budget,
      executable: _browserExecutable,
      arguments: [..._browserPrefixArguments, BrowserNoop.argument, browserPreflightUrl],
      environment: environment,
    )) {
      throw const AntigravityProfileException(message: "Browser suppression could not be verified", cause: null);
    }
    budget.remaining;
    await _repository.preparePersonalOauth(budget: budget);
    budget.remaining;
    return AntigravityPreparedProfile(geminiHome: _repository.geminiHome, environment: environment);
  }

  static String _quote({required String argument}) => "'${argument.replaceAll("'", "'\"'\"'")}'";
}
