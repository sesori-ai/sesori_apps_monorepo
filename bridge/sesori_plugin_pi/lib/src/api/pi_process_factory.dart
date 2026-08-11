import "dart:io";

import "pi_launch_spec.dart";

/// The process surface used by Pi's JSONL transport.
abstract class PiProcessHandle {
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
  IOSink get stdin;
  Future<int> get exitCode;
  bool kill({ProcessSignal signal = ProcessSignal.sigterm});
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
  );
  return _RealPiProcess(process);
}

final class _RealPiProcess implements PiProcessHandle {
  _RealPiProcess(this._process);

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
  bool kill({ProcessSignal signal = ProcessSignal.sigterm}) => _process.kill(signal);
}
