import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "runtime_manifest.dart";
import "runtime_version.dart";

/// Probes a candidate runtime binary's version by running `<bin> --version`.
///
/// Used to decide whether a pre-installed (PATH) runtime is recent enough to use
/// as-is, or whether the bridge should fall back to the managed runtime, and to
/// confirm a freshly-installed managed binary actually runs and reports the
/// expected version.
class RuntimeVersionValidator {
  final CommandExecutor _commandExecutor;
  final String _runtimeId;
  final Duration _probeTimeout;
  final RuntimeManifest _manifest;

  RuntimeVersionValidator({
    required CommandExecutor commandExecutor,
    required RuntimeManifest manifest,
    Duration probeTimeout = const Duration(seconds: 10),
  }) : _commandExecutor = commandExecutor,
       _manifest = manifest,
       _runtimeId = manifest.runtimeId,
       _probeTimeout = probeTimeout;

  /// Runs `<executable> --version` and returns the parsed [RuntimeVersion], or
  /// `null` when the binary cannot be launched, exits non-zero, hangs past the
  /// probe timeout, or prints no parseable version. Never throws.
  Future<RuntimeVersion?> detectVersion({
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
      Log.d("[$_runtimeId] version probe could not run '$executable --version': $error");
      return null;
    }

    if (result.exitCode != 0) {
      Log.d("[$_runtimeId] version probe '$executable --version' exited ${result.exitCode}");
      return null;
    }
    final version = parseVersionOutput(output: result.stdout);
    if (version == null) {
      Log.d("[$_runtimeId] version probe output had no parseable version");
    }
    return version;
  }

  /// Extracts the first whitespace-separated token that parses with the
  /// manifest's version scheme. Every token is tried, and non-version tokens
  /// are skipped. A leading `v`/`V` is stripped so prefixed builds are not
  /// misdetected as unsupported.
  RuntimeVersion? parseVersionOutput({required String output}) {
    for (final rawToken in output.split(RegExp(r"\s+"))) {
      final token = rawToken.trim();
      final candidate = (token.startsWith("v") || token.startsWith("V")) ? token.substring(1) : token;
      final version = _manifest.parseVersion(value: candidate);
      if (version != null) {
        return version;
      }
    }
    return null;
  }
}
