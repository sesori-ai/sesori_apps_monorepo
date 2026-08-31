import "dart:io";

import "package:injectable/injectable.dart";
import "package:meta/meta.dart";

import "../foundation/platform/bridge_process_environment.dart";

/// Starts a child process while keeping the platform calls replaceable in unit
/// tests without introducing a production-only interface.
@visibleForTesting
typedef BridgeProcessStarter = Future<Process> Function({
  required String executable,
  required List<String> arguments,
  required String? workingDirectory,
  required Map<String, String>? environment,
});

/// Runs a short-lived platform process-tree command.
@visibleForTesting
typedef BridgeProcessCommandRunner = Future<ProcessResult> Function({
  required String executable,
  required List<String> arguments,
});

/// Sends an operating-system signal to one process id.
@visibleForTesting
typedef BridgeProcessSignalSender = bool Function({
  required int pid,
  required ProcessSignal signal,
});

/// The raw process resources returned by [BridgeProcessApi.spawn].
class BridgeProcessApiHandle({
  required final int pid,
  required final IOSink stdin,
  required final Stream<List<int>> stdout,
  required final Stream<List<int>> stderr,
  required final Future<int> exitCode,
});

/// Raised before any platform process command can receive an unsafe pid.
final class const InvalidBridgeProcessIdException({required final int pid}) implements Exception {
  @override
  String toString() => "InvalidBridgeProcessIdException: bridge process id must be positive, got $pid";
}

/// Raised when an operating-system process-tree command rejects the kill.
final class const BridgeProcessTreeKillException({
  required final int pid,
  required final String details,
}) implements Exception {
  @override
  String toString() => "BridgeProcessTreeKillException(pid: $pid): $details";
}

/// Layer-1 wrapper around the operating-system child-process primitives used by
/// the desktop bridge supervisor.
///
/// The API is intentionally dumb: it starts a process, exposes raw stdio and
/// exit completion, sends the POSIX graceful signal, and force-kills a whole
/// process tree. Expected-stop semantics belong to the Layer-2 repository.
@lazySingleton
class BridgeProcessApi.forTesting({
  required final bool _isWindows,
  required final BridgeProcessEnvironment _processEnvironment,
  required final BridgeProcessStarter _startProcess,
  required final BridgeProcessCommandRunner _runCommand,
  required final BridgeProcessSignalSender _sendSignal,
}) {
  new({required BridgeProcessEnvironment processEnvironment})
    : this.forTesting(
        isWindows: Platform.isWindows,
        processEnvironment: processEnvironment,
        startProcess: _startProcessDefault,
        runCommand: _runCommandDefault,
        sendSignal: _sendSignalDefault,
      );

  @visibleForTesting
  this;

  /// Resolves the environment overrides before a child is spawned.
  ///
  /// The API owns the platform boundary: callers receive the result through
  /// the repository and can re-check lifecycle cancellation before invoking
  /// [spawn].
  Future<Map<String, String>> resolveEnvironment() => _processEnvironment.resolve();

  Future<BridgeProcessApiHandle> spawn({
    required String executable,
    required List<String> arguments,
    required String? workingDirectory,
    required Map<String, String>? environment,
  }) async {
    // dart:io replaces the inherited environment when a non-null map is
    // supplied, so merge capability-provided overrides before crossing the
    // process boundary. A null value preserves the platform default exactly.
    final Map<String, String>? childEnvironment = environment == null
        ? null
        : <String, String>{...Platform.environment, ...environment};
    final Process process = await _startProcess(
      executable: executable,
      arguments: arguments,
      workingDirectory: workingDirectory,
      environment: childEnvironment,
    );
    try {
      _requirePositivePid(pid: process.pid);
    } on InvalidBridgeProcessIdException {
      process.kill(ProcessSignal.sigkill);
      rethrow;
    }
    return BridgeProcessApiHandle(
      pid: process.pid,
      stdin: process.stdin,
      stdout: process.stdout,
      stderr: process.stderr,
      exitCode: process.exitCode,
    );
  }

  /// Sends the bridge's catchable graceful-stop signal on POSIX.
  ///
  /// Windows has no equivalent catchable SIGTERM contract, so it returns false
  /// and lets the repository move directly to its process-tree fallback when
  /// the control channel is unavailable.
  bool sendGracefulSignal({required int pid}) {
    _requirePositivePid(pid: pid);
    if (_isWindows) {
      return false;
    }
    return _sendSignal(pid: pid, signal: ProcessSignal.sigterm);
  }

  /// Force-kills the helper and every descendant process it owns.
  ///
  /// A supervised POSIX helper makes itself the leader of a dedicated process
  /// group before starting backends, so one verified group signal covers
  /// descendants created at any point during teardown. Windows uses its native
  /// `taskkill /T /F` tree operation.
  Future<void> killProcessTree({required int pid}) async {
    _requirePositivePid(pid: pid);
    if (_isWindows) {
      await _killWindowsProcessTree(pid: pid);
      return;
    }
    _killPosixProcessTree(pid: pid);
  }

  Future<void> _killWindowsProcessTree({required int pid}) async {
    final ProcessResult result = await _runCommand(
      executable: "taskkill",
      arguments: ["/PID", "$pid", "/T", "/F"],
    );
    if (result.exitCode != 0) {
      final String stderr = result.stderr.toString().trim();
      throw BridgeProcessTreeKillException(
        pid: pid,
        details: stderr.isEmpty ? "taskkill exited ${result.exitCode}" : stderr,
      );
    }
  }

  void _killPosixProcessTree({required int pid}) {
    final bool delivered = _sendSignal(pid: -pid, signal: ProcessSignal.sigkill);
    if (!delivered) {
      throw BridgeProcessTreeKillException(
        pid: pid,
        details: "SIGKILL could not be delivered to process group $pid",
      );
    }
  }

  static void _requirePositivePid({required int pid}) {
    if (pid <= 0) {
      throw InvalidBridgeProcessIdException(pid: pid);
    }
  }

  static Future<Process> _startProcessDefault({
    required String executable,
    required List<String> arguments,
    required String? workingDirectory,
    required Map<String, String>? environment,
  }) => Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    runInShell: false,
    mode: ProcessStartMode.normal,
  );

  static Future<ProcessResult> _runCommandDefault({
    required String executable,
    required List<String> arguments,
  }) => Process.run(executable, arguments, runInShell: false);

  static bool _sendSignalDefault({required int pid, required ProcessSignal signal}) => Process.killPid(pid, signal);
}
