import "dart:async";
import "dart:io";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "runtime_manifest.dart";
import "runtime_version.dart";

sealed class const RuntimeProbeOutcome();

final class const RuntimeProbeReady({required final RuntimeVersion version}) extends RuntimeProbeOutcome;

sealed class const RuntimeProbeFailure() extends RuntimeProbeOutcome;

final class RuntimeProbeMissing({required final ProcessException innerError, required final StackTrace stackTrace})
    extends RuntimeProbeFailure;

final class RuntimeProbeTimedOut({required final TimeoutException innerError, required final StackTrace stackTrace})
    extends RuntimeProbeFailure;

final class const RuntimeProbeNonZeroExit({required final int exitCode}) extends RuntimeProbeFailure;

final class const RuntimeProbeUnrecognized() extends RuntimeProbeFailure;

final class RuntimeProbeFailed({required final Object innerError, required final StackTrace stackTrace})
    extends RuntimeProbeFailure;

/// Probes a candidate runtime binary's version by running `<bin> --version`.
///
/// Used to decide whether a pre-installed (PATH) runtime is recent enough to use
/// as-is, or whether the bridge should fall back to the managed runtime, and to
/// confirm a freshly-installed managed binary actually runs and reports the
/// expected version.
class RuntimeVersionValidator({
  required final CommandExecutor _commandExecutor,
  required final RuntimeManifest _manifest,
  final Duration _probeTimeout = const Duration(seconds: 10),
}) {
  /// Runs `<executable> --version` and classifies the result without throwing.
  Future<RuntimeProbeOutcome> probe({
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
    } on ProcessException catch (error, stackTrace) {
      return RuntimeProbeMissing(innerError: error, stackTrace: stackTrace);
    } on TimeoutException catch (error, stackTrace) {
      return RuntimeProbeTimedOut(innerError: error, stackTrace: stackTrace);
    } on Object catch (error, stackTrace) {
      Log.w("[${_manifest.runtimeId}] runtime version probe failed", error, stackTrace);
      return RuntimeProbeFailed(innerError: error, stackTrace: stackTrace);
    }

    if (result.exitCode != 0) {
      return RuntimeProbeNonZeroExit(exitCode: result.exitCode);
    }
    final version = parseVersionOutput(output: result.stdout);
    return version == null ? const RuntimeProbeUnrecognized() : RuntimeProbeReady(version: version);
  }

  /// Returns only the parsed version for callers that do not need failure
  /// classification.
  Future<RuntimeVersion?> detectVersion({
    required String executable,
    required Map<String, String>? environment,
  }) async {
    return switch (await probe(executable: executable, environment: environment)) {
      RuntimeProbeReady(:final version) => version,
      RuntimeProbeFailure() => null,
    };
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
