import "dart:async";
import "dart:convert";
import "dart:io" as io;
import "dart:math";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginHost, ProcessIdentity, SpawnedProcess;
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "codex_ownership_record.dart";

/// Codex runtime policy: everything that decides *how* `codex app-server` is
/// launched, probed, and recorded, expressed over the [PluginHost] services and
/// the shared `sesori_plugin_runtime` supervisor — the same shape the OpenCode
/// plugin uses, adapted for codex's loopback-WebSocket transport.

/// The loopback host `codex app-server` binds its WebSocket listener to and is
/// probed on.
const String codexLoopbackHost = "127.0.0.1";

/// Inclusive bounds of the dynamic (ephemeral) port range used when no explicit
/// `--port` is requested. Codex itself picks an ephemeral port when asked to
/// listen on `:0`, but the supervisor model owns port selection so it can
/// pre-probe bindability and pin the address for ownership/restart bookkeeping.
const int dynamicCodexPortMin = 49152;
const int dynamicCodexPortMax = 65535;

/// Maximum number of dynamic candidates examined before giving up.
const int dynamicCodexMaxAttempts = 5;

/// A sentinel "no reserved port" value for the dynamic policy: codex has no
/// well-known default port to exclude, and 0 never appears in the ephemeral
/// range, so nothing is filtered out.
const int codexNoReservedPort = 0;

/// How long a graceful (SIGTERM) stop waits before escalating to SIGKILL.
const Duration codexGracefulShutdownWait = Duration(seconds: 5);

/// Total budget for the post-spawn health confirmation, probed every
/// [codexHealthPollInterval].
const Duration codexHealthDeadline = Duration(seconds: 30);

/// How often the supervisor re-probes the listening port within
/// [codexHealthDeadline].
const Duration codexHealthPollInterval = Duration(milliseconds: 250);

/// Per-attempt timeout for a single TCP readiness probe.
const Duration codexHealthProbeTimeout = Duration(seconds: 2);

/// Budget for the awaited cold-start in `descriptor.start()`: a server that
/// accepted a TCP connection but stalls the `initialize` handshake must surface
/// as degraded, not hang `start()` under the bridge's cross-instance startup
/// mutex. The cold-start keeps running in the background after the budget.
const Duration codexColdStartBudget = Duration(seconds: 15);

/// Total budget for the pre-start `codex --version` availability probe.
const Duration codexVersionProbeTimeout = Duration(seconds: 10);

/// Crash-restart is disabled for codex: the WebSocket client does not
/// auto-reconnect (a dropped socket fails its in-flight calls), so a restarted
/// `codex app-server` on the same port would not be re-attached. An unexpected
/// child exit therefore surfaces as `PluginFailed` rather than a futile
/// restart loop. Clean shutdowns disarm the monitor first and never fail.
RuntimeRestartPolicy buildCodexRestartPolicy() => const RuntimeRestartPolicy.disabled();

bool _isDynamicCandidate(int port) =>
    port != codexNoReservedPort && port >= dynamicCodexPortMin && port <= dynamicCodexPortMax;

/// The dynamic port candidates the supervisor probes when no explicit port is
/// requested. When [candidates] is supplied (tests) it is filtered through the
/// same in-range rule; otherwise random ports in the dynamic range are drawn,
/// examining at most [dynamicCodexMaxAttempts] draws and yielding each distinct
/// valid candidate (duplicate draws are skipped but still count as attempts, so
/// the loop always terminates).
Iterable<int> codexDynamicCandidates({Iterable<int>? candidates, Random? random}) sync* {
  final supplied = candidates;
  if (supplied != null) {
    var examined = 0;
    for (final port in supplied) {
      if (examined >= dynamicCodexMaxAttempts) {
        return;
      }
      examined++;
      if (_isDynamicCandidate(port)) {
        yield port;
      }
    }
    return;
  }

  final rng = random ?? Random.secure();
  final seen = <int>{};
  // Bound by the number of draws examined, not by distinct ports yielded, so a
  // run of duplicate draws (e.g. a degenerate Random) can never loop forever.
  for (var examined = 0; examined < dynamicCodexMaxAttempts; examined++) {
    final port = dynamicCodexPortMin + rng.nextInt(dynamicCodexPortMax - dynamicCodexPortMin + 1);
    if (_isDynamicCandidate(port) && seen.add(port)) {
      yield port;
    }
  }
}

/// The argument vector `codex app-server` is spawned with for a chosen [port].
/// Kept in one place so the spawn and the ownership record agree byte-for-byte
/// (the supervisor matches a record to a live process by its command line).
List<String> codexAppServerArgs({
  required int port,
  required String? modelCatalogPath,
}) => <String>[
  "app-server",
  if (modelCatalogPath != null) ...[
    "-c",
    // A JSON string is also a valid TOML basic string and safely carries
    // spaces, quotes, and Windows path separators through Codex's `-c` parser.
    "model_catalog_json=${jsonEncode(modelCatalogPath)}",
  ],
  "--listen",
  "ws://$codexLoopbackHost:$port",
];

/// The `ws://` URL the [CodexAppServerClient] connects to for a chosen [port].
String codexServerUrl({required int port}) => "ws://$codexLoopbackHost:$port";

/// Spawns `codex app-server` on [port] through the host's process service,
/// which captures the child's identity. The returned process is wrapped so its
/// stdout/stderr are drained from the moment of spawn — codex logs its listen
/// banner and progress on those streams, and the exit monitor only attaches
/// after `start()` confirms readiness, so without an immediate drain a verbose
/// child could fill the OS pipe and block before answering a probe.
Future<SpawnedProcess> spawnCodexProcess({
  required PluginHost host,
  required String executablePath,
  required int port,
  required String? modelCatalogPath,
}) async {
  final process = await host.processes.spawn(
    executable: executablePath,
    arguments: codexAppServerArgs(
      port: port,
      modelCatalogPath: modelCatalogPath,
    ),
    environment: host.environment,
    workingDirectory: null,
    runInShell: io.Platform.isWindows,
  );
  return _DrainingCodexProcess(process);
}

/// Probes codex readiness on [port] by opening a loopback TCP connection: a
/// successful connect means the WebSocket listener is bound and accepting, which
/// is the readiness gate before the descriptor's cold-start performs the actual
/// `initialize` handshake. Reports unhealthy rather than throwing on any error.
Future<RuntimeHealthProbe> probeCodexHealth({
  required int port,
  Duration timeout = codexHealthProbeTimeout,
}) async {
  try {
    final socket = await io.Socket.connect(codexLoopbackHost, port, timeout: timeout);
    socket.destroy();
    return const RuntimeHealthProbe(healthy: true);
  } on Object catch (error) {
    return RuntimeHealthProbe.unhealthy(error: error);
  }
}

/// Builds the "starting" ownership record from the post-spawn facts. The args
/// mirror [codexAppServerArgs] so the persisted command line matches the live
/// process for supervisor identity matching.
CodexOwnershipRecord buildCodexOwnershipRecord(
  RuntimeRecordDraft draft, {
  required String? modelCatalogPath,
}) {
  return CodexOwnershipRecord(
    ownerSessionId: draft.ownerSessionId,
    codexPid: draft.runtimeIdentity.pid,
    codexStartMarker: draft.runtimeIdentity.startMarker,
    codexExecutablePath: draft.runtimeIdentity.executablePath ?? "",
    codexCommand: draft.runtimeIdentity.executablePath ?? "codex",
    codexArgs: codexAppServerArgs(
      port: draft.port,
      modelCatalogPath: modelCatalogPath,
    ),
    port: draft.port,
    bridgePid: draft.bridgeIdentity.pid,
    bridgeStartMarker: draft.bridgeIdentity.startMarker,
    startedAt: draft.startedAt,
    status: CodexOwnershipStatus.starting,
  );
}

/// Assembles the [ManagedRuntimeSpec] for `codex app-server` with the hardened
/// policy knobs active: deadline-paced health confirmation, the start intent
/// recorded to a bridge-private side file before spawn, and a child exit before
/// the first healthy probe treated as authoritative failure.
ManagedRuntimeSpec<CodexOwnershipRecord> buildCodexManagedRuntimeSpec({
  required PluginHost host,
  required String executablePath,
  required String? modelCatalogPath,
  required RuntimePortPolicy portPolicy,
}) {
  return ManagedRuntimeSpec<CodexOwnershipRecord>(
    spawn: ({required int port}) => spawnCodexProcess(
      host: host,
      executablePath: executablePath,
      port: port,
      modelCatalogPath: modelCatalogPath,
    ),
    probeHealth: probeCodexHealth,
    probePortBindable: ({required int port}) => host.ports.isBindable(host: codexLoopbackHost, port: port),
    buildRecord: (draft) => buildCodexOwnershipRecord(
      draft,
      modelCatalogPath: modelCatalogPath,
    ),
    portPolicy: portPolicy,
    healthPolicy: RuntimeHealthPolicy.deadline(
      deadline: codexHealthDeadline,
      pollInterval: codexHealthPollInterval,
    ),
    recordTiming: RuntimeRecordTiming.intentSideFile,
    failOnEarlyChildExit: true,
  );
}

/// Wraps a [SpawnedProcess] so its stdout/stderr are drained from the moment of
/// spawn, for the child's whole lifetime, so the OS pipe can never fill. The
/// streams are exposed as broadcast so the exit monitor can still attach once
/// armed; output produced before that is consumed by the internal drain.
class _DrainingCodexProcess implements SpawnedProcess {
  _DrainingCodexProcess(this._inner)
    : _stdout = _inner.stdout.asBroadcastStream(),
      _stderr = _inner.stderr.asBroadcastStream() {
    _stdoutDrain = _stdout.listen((_) {}, onError: (Object _) {}, cancelOnError: false);
    _stderrDrain = _stderr.listen((_) {}, onError: (Object _) {}, cancelOnError: false);
    // Fail-soft: this background drain-release is best-effort, so swallow any
    // error (e.g. a `cancel()` throw) rather than leaking an unhandled async
    // error from the unawaited future.
    unawaited(_releaseDrainsOnExit().catchError((Object _) {}));
  }

  final SpawnedProcess _inner;
  final Stream<List<int>> _stdout;
  final Stream<List<int>> _stderr;
  late final StreamSubscription<List<int>> _stdoutDrain;
  late final StreamSubscription<List<int>> _stderrDrain;

  Future<void> _releaseDrainsOnExit() async {
    try {
      await _inner.exitCode;
    } on Object {
      // Ignore: the only purpose here is to release the drains after exit.
    }
    await _stdoutDrain.cancel();
    await _stderrDrain.cancel();
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
