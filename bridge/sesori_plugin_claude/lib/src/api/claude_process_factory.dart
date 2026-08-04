import "dart:io" as io;

import "claude_launch_spec.dart";

/// The slice of `dart:io`'s [io.Process] the Claude transport actually uses.
///
/// Kept narrow so tests can supply an in-memory fake without implementing the
/// full [io.Process] surface.
abstract class ClaudeProcessHandle {
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
  io.IOSink get stdin;
  Future<int> get exitCode;
  bool kill([io.ProcessSignal signal = io.ProcessSignal.sigterm]);
}

/// Spawns a [ClaudeProcessHandle] for a launch spec. Injected into
/// [ClaudeStreamClient] so tests can substitute a fake process.
typedef ClaudeProcessFactory = Future<ClaudeProcessHandle> Function(ClaudeLaunchSpec spec);

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

class _RealClaudeProcess implements ClaudeProcessHandle {
  _RealClaudeProcess(this._process);

  final io.Process _process;

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
