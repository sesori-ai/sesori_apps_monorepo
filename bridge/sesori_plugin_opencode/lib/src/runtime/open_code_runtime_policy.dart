import "dart:convert";
import "dart:io" as io;
import "dart:math";

import "package:http/http.dart" as http;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginHost, SpawnedProcess;
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "open_code_ownership_record.dart";

/// OpenCode-specific runtime policy, re-expressed over the [PluginHost] services
/// instead of the bridge-side `OpenCodeProcessApi` / `OpenCodeServerService`.
///
/// PR 11 of the plugin-lifecycle migration: everything that decides *how*
/// OpenCode is launched, probed, and recorded now lives in the plugin package.
/// The spawn goes through [PluginHost.processes] (which captures identity), the
/// health probe hits `/global/health` with the same Basic-auth scheme, the
/// password is generated the same way, and the port constants are unchanged.
/// The interim duplication with the bridge-side copies is deliberate; the
/// bridge-side copies are deleted in PR 13.

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

/// The loopback host OpenCode binds to and is probed on.
const String openCodeLoopbackHost = "127.0.0.1";

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

bool _isDynamicCandidate(int port) =>
    port != openCodeDefaultPort && port >= dynamicOpenCodePortMin && port <= dynamicOpenCodePortMax;

/// The dynamic port candidates the supervisor probes when no explicit port is
/// requested.
///
/// When [candidates] is supplied (tests), it is filtered through the same
/// reserved/in-range rule and used verbatim. Otherwise random ports in the
/// dynamic range are drawn until [dynamicOpenCodeMaxAttempts] distinct valid
/// candidates have been yielded — matching the legacy generator so the
/// supervisor, which counts every examined candidate against `maxAttempts`,
/// sees the same sequence.
Iterable<int> openCodeDynamicCandidates({Iterable<int>? candidates, Random? random}) sync* {
  final supplied = candidates;
  if (supplied != null) {
    for (final port in supplied) {
      if (_isDynamicCandidate(port)) {
        yield port;
      }
    }
    return;
  }

  final rng = random ?? Random.secure();
  final seen = <int>{};
  while (seen.length < dynamicOpenCodeMaxAttempts) {
    final port = dynamicOpenCodePortMin + rng.nextInt(dynamicOpenCodePortMax - dynamicOpenCodePortMin + 1);
    if (_isDynamicCandidate(port) && seen.add(port)) {
      yield port;
    }
  }
}

/// Spawns `opencode serve` on [port] through the host's process service, which
/// captures the child's identity. The supervisor trusts the returned
/// [SpawnedProcess.identity] and never re-inspects it.
Future<SpawnedProcess> spawnOpenCodeProcess({
  required PluginHost host,
  required String executablePath,
  required int port,
  required String password,
}) {
  final environment = <String, String>{
    ...host.environment,
    "OPENCODE_SERVER_PASSWORD": password,
  };
  return host.processes.spawn(
    executable: executablePath,
    arguments: <String>["serve", "--port", "$port", "--hostname", openCodeLoopbackHost],
    environment: environment,
    workingDirectory: null,
    runInShell: io.Platform.isWindows,
  );
}

/// Probes OpenCode health on [port]: `GET /global/health` with Basic auth
/// `opencode:<password>`, healthy iff the response is HTTP 200 (matching the
/// legacy probe). Reports unhealthy rather than throwing on any error.
Future<RuntimeHealthProbe> probeOpenCodeHealth({
  required int port,
  required String password,
  required http.Client Function() clientFactory,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final client = clientFactory();
  try {
    final uri = Uri.parse("http://$openCodeLoopbackHost:$port/global/health");
    final request = http.Request("GET", uri);
    request.headers["Authorization"] = "Basic ${base64Encode(utf8.encode("opencode:$password"))}";
    final response = await client.send(request).timeout(timeout);
    await response.stream.drain<void>();
    final healthy = response.statusCode == 200;
    return RuntimeHealthProbe(
      healthy: healthy,
      error: healthy ? null : StateError("OpenCode health probe returned HTTP ${response.statusCode}"),
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
OpenCodeOwnershipRecord buildOpenCodeOwnershipRecord(RuntimeRecordDraft draft) {
  return OpenCodeOwnershipRecord(
    ownerSessionId: draft.ownerSessionId,
    openCodePid: draft.runtimeIdentity.pid,
    openCodeStartMarker: draft.runtimeIdentity.startMarker,
    openCodeExecutablePath: draft.runtimeIdentity.executablePath ?? "",
    openCodeCommand: draft.runtimeIdentity.executablePath ?? "opencode",
    openCodeArgs: <String>["serve", "--port", "${draft.port}", "--hostname", openCodeLoopbackHost],
    port: draft.port,
    bridgePid: draft.bridgeIdentity.pid,
    bridgeStartMarker: draft.bridgeIdentity.startMarker,
    startedAt: draft.startedAt,
    status: OpenCodeOwnershipStatus.starting,
  );
}

/// Assembles the [ManagedRuntimeSpec] for OpenCode with the **legacy** policy
/// knobs: five 500 ms health attempts, the ownership record written after spawn,
/// next-candidate retry on port exhaustion, and no extra runtime validation.
///
/// The hardened pacing (deadline health, intent side-file, pre-probe
/// bindability, early-exit detection) becomes the default only when the real
/// descriptor opts in at the flip (PR 12); PR 11 stays byte-for-byte legacy.
ManagedRuntimeSpec<OpenCodeOwnershipRecord> buildOpenCodeManagedRuntimeSpec({
  required PluginHost host,
  required String executablePath,
  required String password,
  required RuntimePortPolicy portPolicy,
  required http.Client Function() probeClientFactory,
}) {
  return ManagedRuntimeSpec<OpenCodeOwnershipRecord>(
    spawn: ({required int port}) =>
        spawnOpenCodeProcess(host: host, executablePath: executablePath, port: port, password: password),
    probeHealth: ({required int port}) =>
        probeOpenCodeHealth(port: port, password: password, clientFactory: probeClientFactory),
    probePortBindable: ({required int port}) => host.ports.isBindable(host: openCodeLoopbackHost, port: port),
    buildRecord: buildOpenCodeOwnershipRecord,
    portPolicy: portPolicy,
    healthPolicy: const RuntimeHealthPolicy.attemptCount(attempts: 5, delay: Duration(milliseconds: 500)),
  );
}
