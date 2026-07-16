import "dart:io";

import "../process/process_identity.dart";
import "../process/signal_result.dart";

/// Process management offered by the bridge to plugins.
///
/// Backed by the bridge's platform-aware process layer: identity capture
/// uses the POSIX `ps` start-time marker where available, with documented
/// Windows fallbacks (no start marker, image-name-only command lines).
abstract class HostProcessService {
  /// Spawns a child process and captures its identity.
  ///
  /// The returned [SpawnedProcess] exposes stdio — including [SpawnedProcess.stdin],
  /// which stdio-speaking plugins (e.g. ACP agents) drive directly. The
  /// plugin owns the child: it must consume (or explicitly drain) stdout and
  /// stderr so the child cannot block on a full pipe, and it must stop the
  /// child during its own `shutdown()`.
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
  });

  /// Captures the identity of the process [pid], or `null` when no such
  /// process is running.
  Future<ProcessIdentity?> inspect({required int pid});

  /// Sends the platform's graceful-stop signal to [pid] (SIGTERM on POSIX;
  /// Windows has no graceful signal and delivers a kill instead — the
  /// returned [SignalResult] records what was actually sent).
  Future<SignalResult> signalGraceful({required int pid});

  /// Forcibly kills [pid] (SIGKILL or platform equivalent).
  Future<SignalResult> signalForce({required int pid});
}

/// A child process spawned through [HostProcessService.spawn].
abstract class SpawnedProcess {
  /// The child's process id.
  int get pid;

  /// The child's identity, captured on a best-effort basis around spawn
  /// time. May be partial (`startMarker` null, command line approximate) —
  /// always on Windows, and on POSIX when the child exits (or the process
  /// table races) before the post-spawn inspection. Consumers must tolerate
  /// partial identities, as [ProcessIdentity.hasSameIdentityAs] does.
  ProcessIdentity get identity;

  /// The child's standard input. Drives stdio protocols (ACP agents).
  IOSink get stdin;

  /// The child's standard output. Single subscription; the plugin must
  /// listen or explicitly drain it.
  Stream<List<int>> get stdout;

  /// The child's standard error. Single subscription; the plugin must
  /// listen or explicitly drain it.
  Stream<List<int>> get stderr;

  /// Completes with the child's exit code when it exits.
  Future<int> get exitCode;
}
