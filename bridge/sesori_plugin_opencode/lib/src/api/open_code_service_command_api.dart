import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show CommandResult, HostProcessCommandExecutor;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show PluginStartAbortedException, StartAbortSignal;
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart" show SemanticRuntimeVersion;

import "../models/open_code_service_command_exception.dart";

/// Layer-1 runner for the OpenCode CLI commands that start OpenCode 2's shared
/// background service. Each method parses its own output and makes no decisions.
/// An abort surfaces as [PluginStartAbortedException].
class const OpenCodeServiceCommandApi({required final HostProcessCommandExecutor executor}) {
  static const Duration _probeTimeout = Duration(seconds: 10);

  /// `service start` waits for the service to be discoverable; OpenCode itself
  /// gives up after 120 s, the bridge after this.
  static const Duration _startTimeout = Duration(seconds: 60);

  Future<SemanticRuntimeVersion> readVersion({
    required String binary,
    required Map<String, String> environment,
    required StartAbortSignal startAborted,
  }) async {
    final result = await _run(
      binary: binary,
      arguments: const ["--version"],
      environment: environment,
      timeout: _probeTimeout,
      startAborted: startAborted,
    );
    // OpenCode 2 prints `opencode v2.0.25`, OpenCode 1 a bare `1.14.30`. Like
    // the setup probe, take the first token that parses, without a leading `v`.
    for (final token in result.stdout.trim().split(RegExp(r"\s+"))) {
      final raw = token.startsWith("v") || token.startsWith("V") ? token.substring(1) : token;
      if (SemanticRuntimeVersion.tryParse(value: raw) case final SemanticRuntimeVersion version) return version;
    }
    throw OpenCodeServiceCommandException(
      message: "'$binary --version' printed '${result.stdout.trim()}'",
      cause: null,
    );
  }

  /// OpenCode's own opt-out, `opencode service set disabled true`.
  Future<bool> readDisabled({
    required String binary,
    required Map<String, String> environment,
    required StartAbortSignal startAborted,
  }) async {
    final result = await _run(
      binary: binary,
      arguments: const ["service", "get", "disabled"],
      environment: environment,
      timeout: _probeTimeout,
      startAborted: startAborted,
    );
    return switch (result.stdout.trim()) {
      "true" => true,
      "false" => false,
      final other => throw OpenCodeServiceCommandException(
        message: "'$binary service get disabled' printed '$other'",
        cause: null,
      ),
    };
  }

  /// Idempotent: reuses a running service, waits for a booting one, and
  /// otherwise spawns OpenCode's detached `serve --service`, which outlives
  /// this command and the bridge.
  Future<void> startService({
    required String binary,
    required Map<String, String> environment,
    required StartAbortSignal startAborted,
  }) async {
    await _run(
      binary: binary,
      arguments: const ["service", "start"],
      environment: environment,
      timeout: _startTimeout,
      startAborted: startAborted,
    );
  }

  Future<CommandResult> _run({
    required String binary,
    required List<String> arguments,
    required Map<String, String> environment,
    required Duration timeout,
    required StartAbortSignal startAborted,
  }) async {
    final command = "'$binary ${arguments.join(" ")}'";
    final CommandResult result;
    try {
      result = await executor.runAbortable(
        executable: binary,
        arguments: arguments,
        workingDirectory: null,
        environment: environment,
        timeout: timeout,
        abortSignal: startAborted,
      );
    } on PluginStartAbortedException {
      rethrow;
    } on Exception catch (error, stackTrace) {
      // Keep the launch or timeout call site for the caller's log.
      Error.throwWithStackTrace(
        OpenCodeServiceCommandException(message: "$command did not finish", cause: error),
        stackTrace,
      );
    }
    if (result.exitCode != 0) {
      final stderrText = result.stderr.trim();
      throw OpenCodeServiceCommandException(
        message: "$command exited ${result.exitCode}",
        cause: stderrText.isEmpty ? null : stderrText,
      );
    }
    return result;
  }
}
