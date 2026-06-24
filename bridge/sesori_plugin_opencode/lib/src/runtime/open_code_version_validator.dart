import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

/// Probes a candidate OpenCode binary's version by running `<bin> --version`.
///
/// Used to decide whether a pre-installed (PATH) OpenCode is recent enough to
/// use as-is, or whether the bridge should fall back to the managed runtime.
class OpenCodeVersionValidator {
  final CommandExecutor _commandExecutor;
  final Duration _probeTimeout;

  OpenCodeVersionValidator({
    required CommandExecutor commandExecutor,
    Duration probeTimeout = const Duration(seconds: 10),
  }) : _commandExecutor = commandExecutor,
       _probeTimeout = probeTimeout;

  /// Runs `<executable> --version` and returns the parsed [SemanticVersion], or
  /// `null` when the binary cannot be launched, exits non-zero, hangs past the
  /// probe timeout, or prints no parseable version. Never throws.
  Future<SemanticVersion?> detectVersion({
    required String executable,
    required Map<String, String>? environment,
  }) async {
    final CommandResult result;
    try {
      result = await _commandExecutor.run(
        executable,
        const ["--version"],
        environment: environment,
        timeout: _probeTimeout,
      );
    } on Object catch (error) {
      // Almost always ENOENT (not installed / not on PATH) or a probe timeout.
      Log.d("[opencode] version probe could not run '$executable --version': $error");
      return null;
    }

    if (result.exitCode != 0) {
      Log.d("[opencode] version probe '$executable --version' exited ${result.exitCode}");
      return null;
    }
    return _parseVersion(result.stdout);
  }

  /// Extracts the first whitespace-separated token that parses as a semantic
  /// version. OpenCode prints a bare `X.Y.Z`, but a leading `v`/`V` (e.g.
  /// `v1.17.9`) is stripped so a prefixed build is not misdetected as
  /// unsupported.
  SemanticVersion? _parseVersion(String output) {
    for (final rawToken in output.split(RegExp(r"\s+"))) {
      final token = rawToken.trim();
      final candidate = (token.startsWith("v") || token.startsWith("V")) ? token.substring(1) : token;
      final version = SemanticVersion.tryParse(value: candidate);
      if (version != null) {
        return version;
      }
    }
    Log.d("[opencode] version probe output had no parseable version: '${output.trim()}'");
    return null;
  }
}
