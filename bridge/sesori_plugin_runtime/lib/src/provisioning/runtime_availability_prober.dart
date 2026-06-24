import "dart:async";
import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show HostProcessService, Log, PluginAvailability, PluginAvailable, PluginUnavailable, SpawnedProcess;

/// Probes whether a runtime binary at a given path is launchable and answers
/// `--version`, classifying the outcome into a [PluginAvailability].
///
/// This is the read-only availability check a descriptor runs (before the
/// startup mutex) on an explicitly-configured backend binary. It spawns through
/// the host's [HostProcessService] (never a raw spawn), drains stdout/stderr so
/// a chatty child can't block on a full pipe, bounds the probe with a timeout,
/// and force-kills a child that outlives it. Never throws: every failure maps to
/// a [PluginUnavailable] carrying user-facing install/verify guidance.
class RuntimeAvailabilityProber {
  const RuntimeAvailabilityProber({
    required this.displayName,
    required this.installDocsUrl,
    required this.runtimeId,
  });

  /// Human-readable backend name used in the guidance messages (e.g. "Codex").
  final String displayName;

  /// Manual install/upgrade URL surfaced in the guidance messages.
  final String installDocsUrl;

  /// Stable backend id used only for diagnostic log tagging (e.g. "codex").
  final String runtimeId;

  /// Runs `<executablePath> --version` through [processes] and classifies the
  /// outcome. `exit 0` within [versionProbeTimeout] is [PluginAvailable];
  /// anything else is [PluginUnavailable] with guidance. Never throws.
  Future<PluginAvailability> probe({
    required String executablePath,
    required HostProcessService processes,
    required Map<String, String> environment,
    required Duration versionProbeTimeout,
    required bool runInShell,
  }) async {
    final SpawnedProcess process;
    try {
      process = await processes.spawn(
        executable: executablePath,
        arguments: const ["--version"],
        environment: environment,
        workingDirectory: null,
        runInShell: runInShell,
      );
    } on Object catch (error) {
      // Spawn could not launch at all — almost always ENOENT: the binary is not
      // installed or not on PATH.
      Log.d("[$runtimeId] availability probe could not launch '$executablePath --version': $error");
      return PluginUnavailable(message: _notInstalledMessage(executablePath: executablePath));
    }

    // Accumulate stdout (the version string, for diagnostics) and drain stderr
    // so the child can never block on a full pipe. Subscriptions, not joined
    // futures, so a hung binary that never closes its streams cannot keep us
    // waiting past the timeout below.
    final stdoutBuffer = StringBuffer();
    final stdoutSubscription = process.stdout.transform(utf8.decoder).listen(
      stdoutBuffer.write,
      onError: (Object error, StackTrace stackTrace) =>
          Log.w("[$runtimeId] version-probe stdout stream error", error, stackTrace),
    );
    final stderrSubscription = process.stderr.listen(
      (_) {},
      onError: (Object error, StackTrace stackTrace) =>
          Log.w("[$runtimeId] version-probe stderr stream error", error, stackTrace),
    );
    try {
      final exitCode = await process.exitCode.timeout(versionProbeTimeout);
      if (exitCode == 0) {
        final version = stdoutBuffer.toString().trim();
        Log.d("[$runtimeId] available: '$executablePath --version' -> ${version.isEmpty ? "exit 0 (no output)" : version}");
        return const PluginAvailable();
      }
      Log.d("[$runtimeId] availability probe '$executablePath --version' exited with code $exitCode");
      return PluginUnavailable(message: _notWorkingMessage(executablePath: executablePath));
    } on TimeoutException {
      Log.d(
        "[$runtimeId] availability probe '$executablePath --version' did not exit within "
        "${versionProbeTimeout.inSeconds}s",
      );
      try {
        await processes.signalForce(pid: process.pid);
      } on Object catch (error, stackTrace) {
        // Best-effort: reap the hung probe so it does not linger.
        Log.w("[$runtimeId] failed to reap a hung version probe (pid ${process.pid})", error, stackTrace);
      }
      return PluginUnavailable(message: _notWorkingMessage(executablePath: executablePath));
    } on Object catch (error) {
      Log.d("[$runtimeId] availability probe '$executablePath --version' failed with error: $error");
      return PluginUnavailable(message: _notWorkingMessage(executablePath: executablePath));
    } finally {
      await stdoutSubscription.cancel();
      await stderrSubscription.cancel();
    }
  }

  /// Message for "the backend binary could not be found / launched".
  String _notInstalledMessage({required String executablePath}) {
    return [
      "$displayName was not found — the Sesori bridge needs the $displayName CLI to run.",
      "",
      ..._alignedRows({
        "Verify it is installed:": "$executablePath --version",
        "Install $displayName:": installDocsUrl,
      }),
    ].join("\n");
  }

  /// Message for "the backend binary was found but `--version` failed/hung".
  String _notWorkingMessage({required String executablePath}) {
    return [
      '$displayName is installed but did not respond to "$executablePath --version".',
      "",
      ..._alignedRows({
        "Re-check your install:": "$executablePath --version",
        "Reinstall $displayName:": installDocsUrl,
      }),
    ].join("\n");
  }

  /// Renders `label  value` rows with the labels padded to a common width so the
  /// values line up, regardless of the (variable-length) display name.
  List<String> _alignedRows(Map<String, String> rows) {
    final int width = rows.keys.map((label) => label.length).reduce((a, b) => a > b ? a : b);
    return [
      for (final entry in rows.entries) "${entry.key.padRight(width)}  ${entry.value}",
    ];
  }
}
