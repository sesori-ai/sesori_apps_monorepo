import "dart:async";
import "dart:io";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginStartAbortedException;

import "runtime_candidate_validator.dart";
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
/// Used to decide whether a pre-installed PATH runtime is recent enough to use
/// as-is, whether the PATH command is genuinely absent so managed fallback is
/// allowed, and whether a freshly installed managed binary runs and reports the
/// expected version.
class RuntimeVersionValidator({
  required final CommandExecutor _commandExecutor,
  required final RuntimeManifest _manifest,
  final Duration _probeTimeout = const Duration(seconds: 10),
  required HostExecutableLocator executableLocator,
}) implements RuntimeCandidateValidator {
  final HostExecutableLocator _executableLocator = executableLocator;

  /// Runs `<executable> --version` and classifies the result without throwing.
  Future<RuntimeProbeOutcome> probe({
    required String executable,
    required Map<String, String>? environment,
  }) => _probe(executable: executable, environment: environment, workingDirectory: null);

  Future<RuntimeProbeOutcome> _probe({
    required String executable,
    required Map<String, String>? environment,
    required String? workingDirectory,
  }) async {
    final CommandResult result;
    try {
      result = await _commandExecutor.run(
        executable,
        const ["--version"],
        workingDirectory: workingDirectory,
        environment: environment,
        timeout: _probeTimeout,
      );
    } on ProcessException catch (error, stackTrace) {
      if (_isMissingProcessError(error: error) &&
          _executableLocator.locate(
                executable: executable,
                environment: environment,
                workingDirectory: workingDirectory,
              ) ==
              HostExecutablePresence.absent) {
        return RuntimeProbeMissing(innerError: error, stackTrace: stackTrace);
      }
      Log.w(
        "[${_manifest.runtimeId}] runtime version probe could not launch '$executable --version'",
        error,
        stackTrace,
      );
      return RuntimeProbeFailed(innerError: error, stackTrace: stackTrace);
    } on TimeoutException catch (error, stackTrace) {
      Log.w("[${_manifest.runtimeId}] runtime version probe timed out for '$executable --version'", error, stackTrace);
      return RuntimeProbeTimedOut(innerError: error, stackTrace: stackTrace);
    } on Object catch (error, stackTrace) {
      Log.w("[${_manifest.runtimeId}] runtime version probe failed for '$executable --version'", error, stackTrace);
      return RuntimeProbeFailed(innerError: error, stackTrace: stackTrace);
    }

    if (result.exitCode != 0) {
      if (_executableLocator.isWindows &&
          _executableLocator.locate(
                executable: executable,
                environment: environment,
                workingDirectory: workingDirectory,
              ) ==
              HostExecutablePresence.absent) {
        return RuntimeProbeMissing(
          innerError: ProcessException(
            executable,
            const ["--version"],
            "${result.stdout}\n${result.stderr}".trim(),
            result.exitCode,
          ),
          stackTrace: StackTrace.empty,
        );
      }
      Log.d("[${_manifest.runtimeId}] runtime version probe '$executable --version' exited ${result.exitCode}");
      return RuntimeProbeNonZeroExit(exitCode: result.exitCode);
    }
    final version = parseVersionOutput(output: result.stdout);
    if (version == null) {
      Log.d("[${_manifest.runtimeId}] runtime version probe '$executable --version' returned an unrecognized version");
      return const RuntimeProbeUnrecognized();
    }
    return RuntimeProbeReady(version: version);
  }

  /// Validates an install candidate with the existing exact bundled-version
  /// check. The command executor retains its bounded run-to-completion
  /// behavior; abort is observed before and after that awaited command rather
  /// than falsely promising instant cancellation of an uninterruptible call.
  @override
  Future<bool> validate({required RuntimeCandidateValidationContext context}) async {
    _throwIfAborted(context: context);
    final outcome = await _probe(
      executable: context.executablePath,
      environment: context.environment,
      workingDirectory: context.workingDirectory,
    );
    _throwIfAborted(context: context);
    switch (outcome) {
      case RuntimeProbeReady(:final version):
        final matches = version.compareTo(_manifest.bundledVersion) == 0;
        if (!matches) {
          Log.w(
            "[${_manifest.runtimeId}] candidate '${context.executablePath}' reported '${version.toString()}'; "
            "expected '${_manifest.bundledVersion.toString()}'",
          );
        }
        return matches;
      case RuntimeProbeMissing(:final innerError, :final stackTrace):
        Log.w(
          "[${_manifest.runtimeId}] candidate '${context.executablePath}' could not be launched",
          innerError,
          stackTrace,
        );
        return false;
      case RuntimeProbeFailure():
        return false;
    }
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

  bool _isMissingProcessError({required ProcessException error}) {
    // POSIX ENOENT and Windows ERROR_FILE_NOT_FOUND / ERROR_PATH_NOT_FOUND.
    return error.errorCode == 2 || (_executableLocator.isWindows && error.errorCode == 3);
  }

  void _throwIfAborted({required RuntimeCandidateValidationContext context}) {
    if (context.abortSignal.isAborted) {
      throw const PluginStartAbortedException();
    }
  }
}
