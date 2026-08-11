import "dart:io";

import "pi_launch_spec.dart";

/// The slice of [Process] Pi's JSONL transport actually uses.
///
/// Kept narrow so tests can supply an in-memory fake without implementing the
/// full [Process] surface.
abstract class PiProcessHandle {
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
  IOSink get stdin;
  Future<int> get exitCode;
  bool kill({required ProcessSignal signal});
}

/// Spawns one Pi process for a launch specification.
typedef PiProcessFactory = Future<PiProcessHandle> Function({required PiLaunchSpec spec});

/// Spawns Pi while preserving the user's inherited environment.
Future<PiProcessHandle> defaultPiProcessFactory({required PiLaunchSpec spec}) async {
  final process = await Process.start(
    spec.binaryPath,
    spec.arguments,
    workingDirectory: spec.workingDirectory,
    environment: spec.environment,
    includeParentEnvironment: true,
    runInShell: Platform.isWindows,
  );
  return _RealPiProcess(process: process);
}

class _RealPiProcess implements PiProcessHandle {
  _RealPiProcess({required Process process}) : _process = process;

  final Process _process;

  @override
  Stream<List<int>> get stdout => _process.stdout;

  @override
  Stream<List<int>> get stderr => _process.stderr;

  @override
  IOSink get stdin => _process.stdin;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  bool kill({required ProcessSignal signal}) => _process.kill(signal);
}
