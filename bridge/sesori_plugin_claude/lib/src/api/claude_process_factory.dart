import "dart:async";
import "dart:io" as io;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "claude_launch_spec.dart";

/// The slice of `dart:io`'s [io.Process] the Claude transport actually uses.
///
/// Kept narrow so tests can supply an in-memory fake without implementing the
/// full [io.Process] surface.
abstract class ClaudeProcessHandle() {
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
  io.IOSink get stdin;
  Future<int> get exitCode;
  bool kill([io.ProcessSignal signal = io.ProcessSignal.sigterm]);
}

/// Spawns a [ClaudeProcessHandle] for a launch spec. Injected into
/// [ClaudeStreamClient] so tests can substitute a fake process.
typedef ClaudeProcessFactory = Future<ClaudeProcessHandle> Function(ClaudeLaunchSpec spec);

sealed class const ClaudeProcessSpawnEvent();

final class const ClaudeProcessSpawnSucceeded() extends ClaudeProcessSpawnEvent;

final class const ClaudeProcessSpawnFailed() extends ClaudeProcessSpawnEvent;

/// Routes Claude children through the bridge host and reports binary spawn
/// outcomes separately from per-session process exits.
final class HostClaudeProcessFactory({
  required final HostProcessService _processes,
  required Map<String, String> environment,
}) {
  final Map<String, String> _environment = Map.unmodifiable(environment);
  final StreamController<ClaudeProcessSpawnEvent> _events = StreamController.broadcast();

  Stream<ClaudeProcessSpawnEvent> get events => _events.stream;

  Future<ClaudeProcessHandle> spawn(ClaudeLaunchSpec spec) async {
    try {
      final process = await _processes.spawn(
        executable: spec.binaryPath,
        arguments: spec.arguments,
        environment: {..._environment, ...spec.environment},
        workingDirectory: spec.workingDirectory,
        runInShell: io.Platform.isWindows,
      );
      if (!_events.isClosed) _events.add(const ClaudeProcessSpawnSucceeded());
      return _HostClaudeProcessHandle(process: process, processes: _processes);
    } on Object {
      if (!_events.isClosed) _events.add(const ClaudeProcessSpawnFailed());
      rethrow;
    }
  }

  Future<void> dispose() => _events.close();
}

final class _HostClaudeProcessHandle({
  required final SpawnedProcess _process,
  required final HostProcessService _processes,
}) implements ClaudeProcessHandle {
  @override
  Stream<List<int>> get stdout => _process.stdout;

  @override
  Stream<List<int>> get stderr => _process.stderr;

  @override
  io.IOSink get stdin => _process.stdin;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  bool kill([io.ProcessSignal signal = io.ProcessSignal.sigterm]) {
    unawaited(_signal(force: signal == io.ProcessSignal.sigkill));
    return true;
  }

  Future<void> _signal({required bool force}) async {
    try {
      await (force ? _processes.signalForce(pid: _process.pid) : _processes.signalGraceful(pid: _process.pid));
    } on Object catch (error, stackTrace) {
      Log.w("[claude] failed to signal process ${_process.pid}", error, stackTrace);
    }
  }
}

/// Default factory: spawns a real OS process via [io.Process.start].
///
/// `runInShell` on Windows is required because an npm-installed `claude` is a
/// `.cmd` shim rather than a native executable.
Future<ClaudeProcessHandle> defaultClaudeProcessFactory(ClaudeLaunchSpec spec) async {
  final process = await io.Process.start(
    spec.binaryPath,
    spec.arguments,
    workingDirectory: spec.workingDirectory,
    // includeParentEnvironment defaults to true, so these entries merge over
    // the inherited environment. That inheritance is what lets the CLI find the
    // user's existing login.
    environment: spec.environment,
    runInShell: io.Platform.isWindows,
  );
  return _RealClaudeProcess(process);
}

class _RealClaudeProcess(final io.Process _process) implements ClaudeProcessHandle {
  @override
  Stream<List<int>> get stdout => _process.stdout;

  @override
  Stream<List<int>> get stderr => _process.stderr;

  @override
  io.IOSink get stdin => _process.stdin;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  bool kill([io.ProcessSignal signal = io.ProcessSignal.sigterm]) => _process.kill(signal);
}
