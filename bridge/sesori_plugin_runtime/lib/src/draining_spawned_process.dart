import "dart:async";
import "dart:io" as io;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, ProcessIdentity, SpawnedProcess;

final class DrainingSpawnedProcess({required SpawnedProcess inner}) implements SpawnedProcess {
  final SpawnedProcess _inner = inner;
  final Stream<List<int>> _stdout = inner.stdout.asBroadcastStream();
  final Stream<List<int>> _stderr = inner.stderr.asBroadcastStream();

  this {
    // Keep both pipes flowing through EOF. A process can report its exit code
    // before trailing output reaches the stream, so exit is not a release
    // signal for these drains.
    unawaited(_drain(stream: _stdout, name: "stdout"));
    unawaited(_drain(stream: _stderr, name: "stderr"));
    unawaited(_observeExit());
  }

  Future<void> _drain({required Stream<List<int>> stream, required String name}) async {
    try {
      await stream.drain<void>();
    } on Object catch (error, stackTrace) {
      Log.w("[runtime] $name drain failed", error, stackTrace);
    }
  }

  Future<void> _observeExit() async {
    try {
      await _inner.exitCode;
    } on Object catch (error, stackTrace) {
      Log.w("[runtime] process exit observation failed", error, stackTrace);
    }
  }

  @override
  int get pid => _inner.pid;

  @override
  ProcessIdentity get identity => _inner.identity;

  @override
  io.IOSink get stdin => _inner.stdin;

  @override
  Stream<List<int>> get stdout => _stdout;

  @override
  Stream<List<int>> get stderr => _stderr;

  @override
  Future<int> get exitCode => _inner.exitCode;
}
