import "dart:io" as io;

/// How to spawn an ACP agent subprocess.
///
/// ACP agents (e.g. `cursor-agent acp`, `gemini --experimental-acp`) speak
/// JSON-RPC over their own stdin/stdout. The bridge resolves the binary and
/// hands this spec to the plugin, which spawns the process and owns its
/// lifecycle.
class AcpLaunchSpec {
  const AcpLaunchSpec({
    required this.command,
    required this.args,
    this.cwd,
    this.environment = const {},
  });

  /// Executable to run (absolute path or a name resolved on PATH).
  final String command;

  /// Arguments — typically ends with the ACP subcommand, e.g. `["acp"]`.
  final List<String> args;

  /// Working directory for the agent process. `null` inherits the bridge's.
  final String? cwd;

  /// Extra environment entries merged over the inherited environment
  /// (e.g. `CURSOR_API_KEY`).
  final Map<String, String> environment;
}

/// The slice of `dart:io`'s [io.Process] the ACP transport actually uses.
///
/// Kept narrow so tests can supply an in-memory fake without implementing the
/// full [io.Process] surface (analogous to codex's injected
/// `CodexWebSocketChannelFactory`).
abstract class AcpProcessHandle {
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
  io.IOSink get stdin;
  Future<int> get exitCode;
  bool kill([io.ProcessSignal signal = io.ProcessSignal.sigterm]);
}

/// Spawns an [AcpProcessHandle] for the given [AcpLaunchSpec]. Injected into
/// [AcpStdioClient] so tests can substitute a fake process.
typedef AcpProcessFactory = Future<AcpProcessHandle> Function(AcpLaunchSpec spec);

/// Default factory: spawns a real OS process via [io.Process.start].
Future<AcpProcessHandle> defaultAcpProcessFactory(AcpLaunchSpec spec) async {
  final env = <String, String>{
    ...io.Platform.environment,
    ...spec.environment,
  };
  final process = await io.Process.start(
    spec.command,
    spec.args,
    workingDirectory: spec.cwd,
    environment: env,
    runInShell: io.Platform.isWindows,
  );
  return _RealAcpProcess(process);
}

class _RealAcpProcess implements AcpProcessHandle {
  _RealAcpProcess(this._process);

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
  bool kill([io.ProcessSignal signal = io.ProcessSignal.sigterm]) =>
      _process.kill(signal);
}
