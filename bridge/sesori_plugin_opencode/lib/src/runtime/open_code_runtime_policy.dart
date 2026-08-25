import "dart:async";
import "dart:convert";
import "dart:io" as io;
import "dart:math";

import "package:http/http.dart" as http;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart"
    show
        deviceCanvasAgentToolBootstrapFileEnvironment,
        deviceCanvasAgentToolBootstrapSecretEnvironment,
        deviceCanvasAgentToolReadyFileEnvironment,
        deviceCanvasAgentToolRendezvousEnvironment,
        writeRestrictedFile;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show HostPortService, PluginHost, SpawnedProcess;
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "open_code_ownership_record.dart";

/// OpenCode-specific launch, health-probe, and ownership-record policy over
/// services exposed by [PluginHost].

/// The reserved default port OpenCode listens on, excluded from dynamic
/// discovery.
const int openCodeDefaultPort = 4096;

/// Inclusive bounds of the dynamic (ephemeral) port range used when no explicit
/// `--port` is given.
const int dynamicOpenCodePortMin = 49152;
const int dynamicOpenCodePortMax = 65535;

/// Maximum number of dynamic candidates examined before giving up — bounds
/// discovery exactly like the legacy five-candidate cap.
const int dynamicOpenCodeMaxAttempts = 5;

/// How long a graceful (SIGTERM) stop waits before escalating to SIGKILL.
const Duration openCodeGracefulShutdownWait = Duration(seconds: 5);

/// Total budget for the post-spawn health confirmation (the flip's deadline
/// pacing, replacing the legacy five 500 ms attempts), probed every
/// [openCodeHealthPollInterval].
const Duration openCodeHealthDeadline = Duration(seconds: 30);

/// How often the supervisor re-probes `/global/health` within
/// [openCodeHealthDeadline].
const Duration openCodeHealthPollInterval = Duration(milliseconds: 500);

/// Budget for the awaited cold-start in `descriptor.start()`: a service that
/// passed the health probe but stalls a REST call must surface as degraded,
/// not hang `start()` under the bridge's cross-instance startup mutex. The
/// cold-start keeps running in the background after the budget elapses.
const Duration openCodeColdStartBudget = Duration(seconds: 15);

/// Total budget for the pre-start `opencode --version` availability probe. A
/// binary that hangs instead of promptly printing its version must not stall
/// bridge startup, so the probe is treated as unavailable once this elapses.
const Duration openCodeVersionProbeTimeout = Duration(seconds: 10);

/// The default host OpenCode binds to (and the loopback fallback used when the
/// bind host is a wildcard the bridge cannot connect to).
const String openCodeLoopbackHost = "127.0.0.1";

/// Resolves the host the bridge connects to (HTTP/SSE/health) from the host
/// OpenCode binds to.
///
/// A wildcard bind address is not a connectable client target, so the bridge
/// reaches the server over loopback in the **same address family** to avoid
/// failing on IPv6-only sockets: `0.0.0.0` -> `127.0.0.1`, `::` -> `::1`. Any
/// other value (loopback or a concrete interface address) is reachable directly
/// and is used verbatim.
String resolveOpenCodeConnectHost({required String bindHost}) {
  if (bindHost == "0.0.0.0") {
    return openCodeLoopbackHost;
  }
  if (bindHost == "::") {
    return "::1";
  }
  return bindHost;
}

/// Whether [port] is free for a managed OpenCode start, probed across both the
/// host OpenCode will bind and the host the bridge will dial.
///
/// A single-address bind probe is not enough when the two differ. With a
/// wildcard bind (`0.0.0.0`/`::`) the connect host is a specific loopback
/// (`127.0.0.1`/`::1`), and the OS lets a wildcard bind and a specific-address
/// listener on the same port coexist: a `ServerSocket.bind("0.0.0.0", port)`
/// probe succeeds even though something already holds `127.0.0.1:port`, and the
/// reverse is also true. Probing only one host therefore lets a foreign server
/// already listening on the *other* address slip through pre-start, after which
/// the spawned child co-binds the wildcard, never exits, and the health probe —
/// dialing the connect host — is answered by that foreign listener.
///
/// Requiring **every** distinct host to be bindable closes both gaps: the
/// connect-host probe catches a specific-address squatter and the bind-host
/// probe catches a wildcard squatter. When the two hosts are equal (loopback or
/// a concrete interface address) this collapses to a single probe.
///
/// The distinct hosts are probed **sequentially**, not concurrently. Each probe
/// opens a real `ServerSocket` for the duration of the bind check, and on
/// platforms where a wildcard bind and a same-port specific-address bind are
/// mutually exclusive (notably Linux, a bridge build target) a concurrent probe
/// would have one host's open socket make the other host's probe report `false`
/// — falsely rejecting a genuinely free port. Probing one host at a time means
/// no probe is ever live while another runs, so only a real foreign listener
/// (never our own probe) can fail a bind.
Future<bool> probeOpenCodePortBindable({
  required HostPortService ports,
  required int port,
  required String bindHost,
  required String connectHost,
}) async {
  final hosts = <String>{bindHost, connectHost};
  for (final host in hosts) {
    if (!await ports.isBindable(host: host, port: port)) {
      return false;
    }
  }
  return true;
}

/// Maximum crash-restarts attempted within one failure episode before the
/// monitor reports `PluginFailed`.
const int openCodeRestartMaxAttempts = 3;

/// Backoff before the first restart attempt; grows geometrically (capped at
/// [openCodeRestartMaxBackoff]) on subsequent attempts.
const Duration openCodeRestartInitialBackoff = Duration(seconds: 1);

/// Upper bound on the restart backoff.
const Duration openCodeRestartMaxBackoff = Duration(seconds: 15);

/// How long a restart waits for the address-frozen port to free before the
/// episode is treated as terminal (the HTTP/SSE stack is pinned to the port,
/// so a restart must reclaim that exact address).
const Duration openCodeRestartPortReleaseTimeout = Duration(seconds: 10);

/// How often the pinned port is re-probed while waiting for it to free.
const Duration openCodeRestartPortReleasePollInterval = Duration(milliseconds: 500);

/// Bounded crash-restart pacing for the exit monitor, active since the flip
/// (PR 12): restart on the pinned port with exponential backoff, surfacing
/// `PluginFailed` only when the attempts are exhausted or the port never
/// frees. Clean shutdowns disarm the monitor first and never restart.
RuntimeRestartPolicy buildOpenCodeRestartPolicy() {
  return RuntimeRestartPolicy.bounded(
    maxAttempts: openCodeRestartMaxAttempts,
    initialBackoff: openCodeRestartInitialBackoff,
    maxBackoff: openCodeRestartMaxBackoff,
    portReleaseTimeout: openCodeRestartPortReleaseTimeout,
    portReleasePollInterval: openCodeRestartPortReleasePollInterval,
  );
}

/// Number of random bytes in a generated server password (hex-encoded).
const int openCodePasswordLength = 32;

/// Generates a server password: [openCodePasswordLength] random bytes,
/// lowercase hex-encoded. Set as the `OPENCODE_SERVER_PASSWORD` environment
/// variable (never a CLI flag) and used as the Basic-auth secret.
String generateOpenCodePassword({Random? random}) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(openCodePasswordLength, (_) => rng.nextInt(256));
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, "0")).join();
}

/// The dynamic port candidates the supervisor probes when no explicit port is
/// requested.
Iterable<int> openCodeDynamicCandidates({Iterable<int>? candidates, Random? random}) {
  return dynamicPortCandidates(
    minPort: dynamicOpenCodePortMin,
    maxPort: dynamicOpenCodePortMax,
    maxDraws: dynamicOpenCodeMaxAttempts,
    reservedPort: openCodeDefaultPort,
    candidates: candidates,
    random: random,
  );
}

/// Spawns `opencode serve` on [port] through the host's process service, which
/// captures the child's identity. The supervisor trusts the returned
/// [SpawnedProcess.identity] and never re-inspects it.
///
/// The returned process is wrapped so its stdout/stderr are drained from the
/// moment of spawn: the supervisor's exit
/// monitor only attaches *after* `start()` has confirmed health, so without an
/// immediate drain a verbose `opencode serve` could fill the OS pipe buffer and
/// block before it ever answers the health probe. The legacy path drained both
/// streams immediately after spawning; this preserves that.
Future<SpawnedProcess> spawnOpenCodeProcess({
  required PluginHost host,
  required String executablePath,
  required int port,
  required String? password,
  required String bindHost,
  required Map<String, String> environmentOverrides,
}) async {
  final bootstrapSecret = environmentOverrides[deviceCanvasAgentToolBootstrapSecretEnvironment];
  final bootstrapFilePath = environmentOverrides[deviceCanvasAgentToolBootstrapFileEnvironment];
  if ((bootstrapSecret == null || bootstrapSecret.isEmpty) !=
      (bootstrapFilePath == null || bootstrapFilePath.isEmpty)) {
    throw StateError("Device Canvas agent-tool bootstrap configuration is incomplete");
  }
  if (bootstrapSecret != null && bootstrapSecret.isNotEmpty && bootstrapFilePath != null) {
    await writeRestrictedFile(filePath: bootstrapFilePath, contents: bootstrapSecret);
  }
  final readyFilePath = environmentOverrides[deviceCanvasAgentToolReadyFileEnvironment];
  if (readyFilePath != null && readyFilePath.isNotEmpty) {
    final readyFile = io.File(readyFilePath);
    try {
      readyFile.deleteSync();
    } on io.FileSystemException {
      if (readyFile.existsSync()) rethrow;
    }
  }
  final childOverrides = <String, String>{...environmentOverrides}
    ..remove(deviceCanvasAgentToolBootstrapSecretEnvironment);
  final environment = <String, String>{...host.environment}
    ..remove(deviceCanvasAgentToolBootstrapFileEnvironment)
    ..remove(deviceCanvasAgentToolBootstrapSecretEnvironment)
    ..remove(deviceCanvasAgentToolRendezvousEnvironment)
    ..remove(deviceCanvasAgentToolReadyFileEnvironment)
    ..addAll(childOverrides);
  if (password == null || password.isEmpty) {
    environment.removeWhere(
      (key, _) => key.toUpperCase() == "OPENCODE_SERVER_PASSWORD",
    );
  } else {
    environment["OPENCODE_SERVER_PASSWORD"] = password;
  }
  try {
    final process = await host.processes.spawn(
      executable: executablePath,
      arguments: <String>["serve", "--port", "$port", "--hostname", bindHost],
      environment: environment,
      workingDirectory: null,
      runInShell: io.Platform.isWindows,
    );
    process.exitCode.whenComplete(() => _removeFileIfPresent(bootstrapFilePath)).ignore();
    return DrainingSpawnedProcess(inner: process);
  } on Object {
    _removeFileIfPresent(bootstrapFilePath);
    rethrow;
  }
}

void _removeFileIfPresent(String? filePath) {
  if (filePath == null || filePath.isEmpty) return;
  final file = io.File(filePath);
  try {
    file.deleteSync();
  } on io.FileSystemException {
    if (file.existsSync()) rethrow;
  }
}

/// Probes OpenCode health on [port]: `GET /global/health` with Basic auth
/// `opencode:<password>` when a password is supplied, or with no auth when
/// [password] is null or empty. Healthy iff the response is HTTP 200 (matching
/// the legacy probe). Reports unhealthy rather than throwing on any error.
Future<RuntimeHealthProbe> probeOpenCodeHealth({
  required int port,
  required String? password,
  required http.Client Function() clientFactory,
  required String host,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final client = clientFactory();
  try {
    // Structured fields (not string interpolation) so an IPv6 literal host is
    // correctly bracketed (e.g. `http://[::1]:port`).
    final uri = Uri(scheme: "http", host: host, port: port, path: "/global/health");
    final request = http.Request("GET", uri);
    if (password != null && password.isNotEmpty) {
      request.headers["Authorization"] = "Basic ${base64Encode(utf8.encode("opencode:$password"))}";
    }
    // One timeout bounds the send AND the body drain together (mirroring the
    // legacy probe): a service that returns headers but never closes the body
    // must fail the attempt, not hang the supervisor under the startup mutex.
    final statusCode = await () async {
      final response = await client.send(request);
      await response.stream.drain<void>();
      return response.statusCode;
    }().timeout(timeout);
    final healthy = statusCode == 200;
    return RuntimeHealthProbe(
      healthy: healthy,
      error: healthy ? null : StateError("OpenCode health probe returned HTTP $statusCode"),
    );
  } on Object catch (error) {
    return RuntimeHealthProbe.unhealthy(error: error);
  } finally {
    client.close();
  }
}

Future<RuntimeHealthProbe> _probeOpenCodeManagedHealth({
  required int port,
  required String? password,
  required http.Client Function() clientFactory,
  required String host,
  required String? deviceCanvasToolsReadyFilePath,
  required String deviceCanvasToolsInitializationDirectory,
}) async {
  final health = await probeOpenCodeHealth(
    port: port,
    password: password,
    clientFactory: clientFactory,
    host: host,
  );
  if (!health.healthy || deviceCanvasToolsReadyFilePath == null || deviceCanvasToolsReadyFilePath.isEmpty) {
    return health;
  }
  final readyFile = io.File(deviceCanvasToolsReadyFilePath);
  if (readyFile.existsSync() && readyFile.readAsStringSync() == "ready") return health;
  final initialization = await _initializeOpenCodeDeviceCanvasTools(
    port: port,
    password: password,
    clientFactory: clientFactory,
    host: host,
    directory: deviceCanvasToolsInitializationDirectory,
  );
  if (!initialization.healthy) return initialization;
  try {
    final ready = readyFile.readAsStringSync();
    if (ready == "ready") return health;
    return RuntimeHealthProbe.unhealthy(error: StateError("Device Canvas agent tools did not become ready"));
  } on Object catch (error) {
    return RuntimeHealthProbe.unhealthy(error: error);
  }
}

Future<RuntimeHealthProbe> _initializeOpenCodeDeviceCanvasTools({
  required int port,
  required String? password,
  required http.Client Function() clientFactory,
  required String host,
  required String directory,
}) async {
  final client = clientFactory();
  try {
    final uri = Uri(
      scheme: "http",
      host: host,
      port: port,
      path: "/experimental/tool/ids",
      queryParameters: <String, String>{"directory": directory},
    );
    final request = http.Request("GET", uri);
    if (password != null && password.isNotEmpty) {
      request.headers["Authorization"] = "Basic ${base64Encode(utf8.encode("opencode:$password"))}";
    }
    final statusCode = await () async {
      final response = await client.send(request);
      await response.stream.drain<void>();
      return response.statusCode;
    }().timeout(const Duration(seconds: 5));
    final healthy = statusCode == 200;
    return RuntimeHealthProbe(
      healthy: healthy,
      error: healthy ? null : StateError("OpenCode tool initialization returned HTTP $statusCode"),
    );
  } on Object catch (error) {
    return RuntimeHealthProbe.unhealthy(error: error);
  } finally {
    client.close();
  }
}

/// Builds the "starting" ownership record from the post-spawn facts, mirroring
/// the legacy `_buildRecord` field-for-field so the persisted bytes are
/// identical.
OpenCodeOwnershipRecord buildOpenCodeOwnershipRecord({required RuntimeRecordDraft draft, required String bindHost}) {
  return OpenCodeOwnershipRecord(
    ownerSessionId: draft.ownerSessionId,
    openCodePid: draft.runtimeIdentity.pid,
    openCodeStartMarker: draft.runtimeIdentity.startMarker,
    openCodeExecutablePath: draft.runtimeIdentity.executablePath ?? "",
    openCodeCommand: draft.runtimeIdentity.executablePath ?? "opencode",
    openCodeArgs: <String>["serve", "--port", "${draft.port}", "--hostname", bindHost],
    port: draft.port,
    bridgePid: draft.bridgeIdentity.pid,
    bridgeStartMarker: draft.bridgeIdentity.startMarker,
    startedAt: draft.startedAt,
    status: OpenCodeOwnershipStatus.starting,
  );
}

/// Assembles the [ManagedRuntimeSpec] for OpenCode with the **hardened** policy
/// knobs active since the flip (PR 12): deadline-paced health confirmation
/// ([openCodeHealthDeadline] probed every [openCodeHealthPollInterval]) and a
/// child exit before the first healthy probe treated as authoritative failure
/// (a healthy response after our child died would be an unrelated process
/// squatting the port).
ManagedRuntimeSpec<OpenCodeOwnershipRecord> buildOpenCodeManagedRuntimeSpec({
  required PluginHost host,
  required String executablePath,
  required String? password,
  required RuntimePortPolicy portPolicy,
  required http.Client Function() probeClientFactory,
  required String bindHost,
  required String connectHost,
  required Map<String, String> environmentOverrides,
}) {
  final deviceCanvasToolsReadyFilePath = environmentOverrides[deviceCanvasAgentToolReadyFileEnvironment];
  return ManagedRuntimeSpec<OpenCodeOwnershipRecord>(
    spawn: ({required int port}) => spawnOpenCodeProcess(
      host: host,
      executablePath: executablePath,
      port: port,
      password: password,
      bindHost: bindHost,
      environmentOverrides: environmentOverrides,
    ),
    probeHealth: ({required int port}) => _probeOpenCodeManagedHealth(
      port: port,
      password: password,
      clientFactory: probeClientFactory,
      host: connectHost,
      deviceCanvasToolsReadyFilePath: deviceCanvasToolsReadyFilePath,
      deviceCanvasToolsInitializationDirectory: host.stateDirectory,
    ),
    probePortBindable: ({required int port}) =>
        probeOpenCodePortBindable(ports: host.ports, port: port, bindHost: bindHost, connectHost: connectHost),
    buildRecord: (draft) => buildOpenCodeOwnershipRecord(draft: draft, bindHost: bindHost),
    portPolicy: portPolicy,
    healthPolicy: RuntimeHealthPolicy(
      deadline: openCodeHealthDeadline,
      pollInterval: openCodeHealthPollInterval,
    ),
  );
}
