import "dart:async";
import "dart:io" as io;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "pi_launch_spec.dart";
import "pi_rpc_startup_extension.dart";

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

/// Routes Pi child processes through the bridge host process seam.
final class HostPiProcessFactory({required final HostProcessService _processes}) {
  final StreamController<ProcessSpawnOutcome> _events = StreamController.broadcast();
  Future<io.File>? _startupExtension;

  Stream<ProcessSpawnOutcome> get events => _events.stream;

  Future<PiProcessHandle> spawn({required PiLaunchSpec spec}) async {
    try {
      final startupExtensionFuture = _startupExtension ??= _writeStartupExtension();
      final io.File startupExtension;
      try {
        startupExtension = await startupExtensionFuture;
      } on Object {
        if (identical(_startupExtension, startupExtensionFuture)) _startupExtension = null;
        rethrow;
      }
      final process = await _processes.spawn(
        includeParentEnvironment: true,
        executable: spec.binaryPath,
        arguments: [...spec.arguments, "--extension", startupExtension.path],
        environment: spec.environment,
        workingDirectory: spec.workingDirectory,
        runInShell: io.Platform.isWindows,
      );
      if (!_events.isClosed) _events.add(ProcessSpawnOutcome.succeeded);
      return _HostPiProcessHandle(process: process, processes: _processes);
    } on Object {
      if (!_events.isClosed) _events.add(ProcessSpawnOutcome.failed);
      rethrow;
    }
  }

  Future<io.File> _writeStartupExtension() async {
    final directory = await io.Directory.systemTemp.createTemp("sesori-pi-rpc-");
    try {
      return await io.File("${directory.path}${io.Platform.pathSeparator}startup.mjs")
          .writeAsString(piRpcStartupExtensionSource);
    } on Object {
      try {
        await directory.delete(recursive: true);
      } on Object catch (error, stackTrace) {
        Log.w("[pi] startup extension cleanup failed", error, stackTrace);
      }
      rethrow;
    }
  }

  Future<void> dispose() async {
    await _events.close();
    final startupExtension = _startupExtension;
    if (startupExtension == null) return;
    final io.File file;
    try {
      file = await startupExtension;
    } on Object {
      // Creation failed explicitly at spawn and cleaned its own directory.
      return;
    }
    await file.parent.delete(recursive: true);
  }
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
