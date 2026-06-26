import "dart:async";
import "dart:io" as io;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../acp_process_factory.dart";

/// Builds an [AcpProcessFactory] that spawns the agent through the bridge's
/// [HostProcessService] instead of calling `io.Process.start` directly.
///
/// The plugin-lifecycle contract requires plugins to route process spawning
/// through the [PluginHost] seams (so the bridge owns identity capture and
/// platform-aware signalling) rather than reaching around the host. This is
/// the ACP equivalent of the default [defaultAcpProcessFactory]: it merges the
/// host [environment] under the launch spec's own entries and hands back an
/// [AcpProcessHandle] backed by the spawned child.
AcpProcessFactory hostProcessAcpFactory({
  required HostProcessService processes,
  required Map<String, String> environment,
}) {
  return (AcpLaunchSpec spec) async {
    final spawned = await processes.spawn(
      executable: spec.command,
      arguments: spec.args,
      environment: {...environment, ...spec.environment},
      workingDirectory: spec.cwd,
      // ACP shims on Windows (e.g. `cursor-agent.cmd`) only resolve through a
      // shell — mirror the default factory's platform handling.
      runInShell: io.Platform.isWindows,
    );
    return HostProcessAcpHandle(process: spawned, processes: processes);
  };
}

/// Adapts a [SpawnedProcess] (from [HostProcessService.spawn]) to the narrow
/// [AcpProcessHandle] the ACP stdio transport drives.
///
/// stdio passes straight through. [kill] maps onto the host's platform-aware
/// signalling: `SIGKILL` → [HostProcessService.signalForce], everything else →
/// [HostProcessService.signalGraceful]. The host calls are fire-and-forget —
/// the transport observes the actual termination through [exitCode], exactly as
/// it does with a real `io.Process`.
class HostProcessAcpHandle implements AcpProcessHandle {
  HostProcessAcpHandle({
    required SpawnedProcess process,
    required HostProcessService processes,
  }) : _process = process,
       _processes = processes;

  final SpawnedProcess _process;
  final HostProcessService _processes;

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
    final pid = _process.pid;
    // Signal delivery is fire-and-forget; the transport observes the actual
    // termination via [exitCode]. Run it inside a guarded async closure so a
    // failure (sync or async — e.g. an already-dead process) is logged and
    // fail-soft rather than escaping as an unobserved async error.
    unawaited(_deliverSignal(pid: pid, force: signal == io.ProcessSignal.sigkill));
    return true;
  }

  Future<void> _deliverSignal({required int pid, required bool force}) async {
    try {
      await (force ? _processes.signalForce(pid: pid) : _processes.signalGraceful(pid: pid));
    } on Object catch (e, st) {
      Log.w("[acp] failed to ${force ? "force" : "gracefully"}-signal process $pid", e, st);
    }
  }
}
