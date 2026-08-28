import "dart:io";

import "package:injectable/injectable.dart";
import "package:meta/meta.dart";

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
  required final BridgeProcessStarter _startProcess,
  required final BridgeProcessCommandRunner _runCommand,
  required final BridgeProcessSignalSender _sendSignal,
}) {
  new()
    : this.forTesting(
        isWindows: Platform.isWindows,
        startProcess: _startProcessDefault,
        runCommand: _runCommandDefault,
        sendSignal: _sendSignalDefault,
      );

  @visibleForTesting
  this;

  Future<BridgeProcessApiHandle> spawn({
    required String executable,
    required List<String> arguments,
    required String? workingDirectory,
    required Map<String, String>? environment,
  }) async {
    final Process process = await _startProcess(
      executable: executable,
      arguments: arguments,
      workingDirectory: workingDirectory,
      environment: environment,
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
  Future<void> killProcessTree({required int pid}) async {
    _requirePositivePid(pid: pid);
    if (_isWindows) {
      await _killWindowsProcessTree(pid: pid);
      return;
    }
    await _killPosixProcessTree(pid: pid);
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

  Future<void> _killPosixProcessTree({required int pid}) async {
    final ProcessResult result = await _runCommand(
      executable: "ps",
      arguments: const ["-axo", "pid=,ppid="],
    );
    if (result.exitCode != 0) {
      final String stderr = result.stderr.toString().trim();
      throw BridgeProcessTreeKillException(
        pid: pid,
        details: stderr.isEmpty ? "ps exited ${result.exitCode}" : stderr,
      );
    }

    final Map<int, List<int>> childrenByParent = <int, List<int>>{};
    for (final String line in result.stdout.toString().split("\n")) {
      final List<String> fields = line.trim().split(RegExp(r"\s+"));
      if (fields.length < 2) {
        continue;
      }
      final int? childPid = int.tryParse(fields[0]);
      final int? parentPid = int.tryParse(fields[1]);
      if (childPid == null || parentPid == null || childPid <= 0) {
        continue;
      }
      childrenByParent.putIfAbsent(parentPid, () => <int>[]).add(childPid);
    }

    final List<int> descendants = <int>[];
    void collectDescendants({required int parentPid}) {
      for (final int childPid in childrenByParent[parentPid] ?? const <int>[]) {
        collectDescendants(parentPid: childPid);
        descendants.add(childPid);
      }
    }

    collectDescendants(parentPid: pid);
    for (final int descendantPid in descendants) {
      _sendSignal(pid: descendantPid, signal: ProcessSignal.sigkill);
    }
    _sendSignal(pid: pid, signal: ProcessSignal.sigkill);
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
