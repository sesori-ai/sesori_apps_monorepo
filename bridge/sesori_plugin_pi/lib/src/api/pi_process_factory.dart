import "dart:io";

import "pi_launch_spec.dart";

/// Concrete adapter exposing the process surface used by Pi's JSONL transport.
class PiProcessHandle {
  PiProcessHandle({required Process process}) : _process = process;

  final Process _process;

  Stream<List<int>> get stdout => _process.stdout;
  Stream<List<int>> get stderr => _process.stderr;
  IOSink get stdin => _process.stdin;
  Future<int> get exitCode => _process.exitCode;
  bool kill({required ProcessSignal signal}) => _process.kill(signal);
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
  return PiProcessHandle(process: process);
}
