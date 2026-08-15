import "dart:async";
import "dart:io" as io;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "pi_launch_spec.dart";

/// The process surface used by Pi's JSONL transport.
abstract class PiProcessHandle() {
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
  io.IOSink get stdin;
  Future<int> get exitCode;
  bool kill({required io.ProcessSignal signal});
}

/// Spawns one Pi process for a launch specification.
typedef PiProcessFactory = Future<PiProcessHandle> Function({required PiLaunchSpec spec});

sealed class const PiProcessSpawnEvent();

final class const PiProcessSpawnSucceeded() extends PiProcessSpawnEvent;

final class const PiProcessSpawnFailed() extends PiProcessSpawnEvent;

/// Routes Pi child processes through the bridge host process seam.
final class HostPiProcessFactory({required final HostProcessService _processes}) {
  final StreamController<PiProcessSpawnEvent> _events = StreamController.broadcast();

  Stream<PiProcessSpawnEvent> get events => _events.stream;

  Future<PiProcessHandle> spawn({required PiLaunchSpec spec}) async {
    try {
      final process = await _processes.spawn(
        executable: spec.binaryPath,
        arguments: spec.arguments,
        environment: spec.environment,
        workingDirectory: spec.workingDirectory,
        runInShell: io.Platform.isWindows,
      );
      if (!_events.isClosed) _events.add(const PiProcessSpawnSucceeded());
      return _HostPiProcessHandle(process: process, processes: _processes);
    } on Object {
      if (!_events.isClosed) _events.add(const PiProcessSpawnFailed());
      rethrow;
    }
  }

  Future<void> dispose() => _events.close();
}

final class _HostPiProcessHandle({
  required final SpawnedProcess _process,
  required final HostProcessService _processes,
}) implements PiProcessHandle {
  @override
  Stream<List<int>> get stdout => _process.stdout;

  @override
  Stream<List<int>> get stderr => _process.stderr;

  @override
  io.IOSink get stdin => _process.stdin;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  bool kill({required io.ProcessSignal signal}) {
    unawaited(_signal(force: signal == io.ProcessSignal.sigkill));
    return true;
  }

  Future<void> _signal({required bool force}) async {
    try {
      await (force ? _processes.signalForce(pid: _process.pid) : _processes.signalGraceful(pid: _process.pid));
    } on Object catch (error, stackTrace) {
      Log.w("[pi] failed to signal process ${_process.pid}", error, stackTrace);
    }
  }
}

/// Spawns Pi while preserving the user's inherited environment.
Future<PiProcessHandle> defaultPiProcessFactory({required PiLaunchSpec spec}) async {
  final process = await io.Process.start(
    spec.binaryPath,
    spec.arguments,
    workingDirectory: spec.workingDirectory,
    environment: spec.environment,
    includeParentEnvironment: true,
    runInShell: io.Platform.isWindows,
  );
  return _IoPiProcessHandle(process: process);
}

final class _IoPiProcessHandle({required final io.Process process}) implements PiProcessHandle {
  final io.Process _process = process;

  @override
  Stream<List<int>> get stdout => _process.stdout;

  @override
  Stream<List<int>> get stderr => _process.stderr;

  @override
  io.IOSink get stdin => _process.stdin;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  bool kill({required io.ProcessSignal signal}) => _process.kill(signal);
}
