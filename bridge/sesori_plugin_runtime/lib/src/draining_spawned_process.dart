import "dart:async";
import "dart:io" as io;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show ProcessIdentity, SpawnedProcess;

final class DrainingSpawnedProcess({required SpawnedProcess inner}) implements SpawnedProcess {
  final SpawnedProcess _inner = inner;
  final Stream<List<int>> _stdout = inner.stdout.asBroadcastStream();
  final Stream<List<int>> _stderr = inner.stderr.asBroadcastStream();

  this {
    _stdoutDrain = _stdout.listen((_) {}, onError: (Object _) {}, cancelOnError: false);
    _stderrDrain = _stderr.listen((_) {}, onError: (Object _) {}, cancelOnError: false);
    // Drain release is best-effort and must not leak an unhandled asynchronous
    // error after the process has already exited.
    unawaited(_releaseDrainsOnExit().catchError((Object _) {}));
  }

  late final StreamSubscription<List<int>> _stdoutDrain;
  late final StreamSubscription<List<int>> _stderrDrain;

  Future<void> _releaseDrainsOnExit() async {
    try {
      await _inner.exitCode;
    } on Object {
      return;
    } finally {
      await _stdoutDrain.cancel();
      await _stderrDrain.cancel();
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
