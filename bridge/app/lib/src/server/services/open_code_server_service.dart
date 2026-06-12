import "dart:io";
import "dart:math";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../models/open_code_ownership_record.dart";
import "../repositories/open_code_ownership_repository.dart";
import "../repositories/open_code_process_repository.dart";
import "../repositories/port_repository.dart";
import "../repositories/process_repository.dart";
import "open_code_supervisor_adapters.dart";

const int openCodeDefaultPort = 4096;
const int dynamicOpenCodePortMin = 49152;
const int dynamicOpenCodePortMax = 65535;
const int dynamicOpenCodeMaxAttempts = 5;
const Duration openCodeGracefulShutdownWait = Duration(seconds: 5);

/// Owns the OpenCode runtime lifecycle behind an unchanged public surface,
/// delegating to the extracted [ManagedProcessService] supervisor.
///
/// PR 10 of the plugin-lifecycle migration: production now exercises the
/// reusable supervisor *before* any OpenCode-specific code moves out of the
/// bridge. The supervisor is configured with the exact legacy policies —
/// five 500 ms health attempts, the ownership record written after spawn, the
/// next-candidate retry on port exhaustion, and the restart / exit-monitor /
/// intent-side-file features all off — so the byte-for-byte ownership file and
/// the observable behavior the 1,224-line fidelity suite pins stay identical.
/// The legacy repositories are reached through thin adapters
/// ([OpenCodeOwnershipStoreAdapter], [OpenCodeHostProcessAdapter],
/// [OpenCodeBridgeHostInfo], [OpenCodeRecordMapper]); identity capture and the
/// dynamic-candidate selection stay here, on the spawn/port seams.
class OpenCodeServerService {
  OpenCodeServerService({
    required OpenCodeProcessRepository openCodeProcessRepository,
    required ProcessRepository processRepository,
    required PortRepository portRepository,
    required OpenCodeOwnershipRepository ownershipRepository,
    required ServerClock clock,
    required ProcessIdentity currentBridgeIdentity,
    required String ownerSessionId,
    required Iterable<int>? candidatePorts,
    required Random? random,
  }) : _openCodeProcessRepository = openCodeProcessRepository,
       _processRepository = processRepository,
       _portRepository = portRepository,
       _candidatePorts = candidatePorts == null ? null : List<int>.from(candidatePorts),
       _random = random ?? Random.secure(),
       _supervisor = ManagedProcessService<OpenCodeOwnershipRecord>(
         ownershipRepository: OpenCodeOwnershipStoreAdapter(repository: ownershipRepository),
         mapper: const OpenCodeRecordMapper(),
         processes: OpenCodeHostProcessAdapter(processRepository: processRepository),
         bridge: OpenCodeBridgeHostInfo(
           processRepository: processRepository,
           identity: currentBridgeIdentity,
           ownerSessionId: ownerSessionId,
         ),
         clock: clock,
         runtimeId: "opencode",
         gracefulShutdownWait: openCodeGracefulShutdownWait,
       );

  final OpenCodeProcessRepository _openCodeProcessRepository;
  final ProcessRepository _processRepository;
  final PortRepository _portRepository;
  final List<int>? _candidatePorts;
  final Random _random;
  final ManagedProcessService<OpenCodeOwnershipRecord> _supervisor;

  Future<OpenCodeServerRuntime> start({
    required String executablePath,
    required int? requestedPort,
    required String? password,
    required Iterable<ProcessIdentity> terminatedBridgeIdentities,
  }) async {
    final serverPassword = password == null || password.isEmpty
        ? _openCodeProcessRepository.generatePassword()
        : password;

    final RuntimePortPolicy portPolicy;
    if (requestedPort != null) {
      Log.d("[OPENCODE] Starting on port $requestedPort");
      // Legacy explicit-port behavior: spawn straight onto the port, no
      // pre-probe (preProbeBindable stays off).
      portPolicy = ExplicitPortPolicy(port: requestedPort);
    } else {
      Log.d("[OPENCODE] Starting on dynamic port");
      portPolicy = DynamicPortPolicy(
        // Candidates are pre-filtered here exactly as before (reserved default
        // port and out-of-range values dropped) so the supervisor — which
        // counts every examined candidate toward maxAttempts — sees the same
        // sequence the legacy five-candidate cap did.
        candidates: _dynamicCandidates(),
        maxAttempts: dynamicOpenCodeMaxAttempts,
        reservedPort: openCodeDefaultPort,
        minPort: dynamicOpenCodePortMin,
        maxPort: dynamicOpenCodePortMax,
      );
    }

    final spec = _buildSpec(executablePath: executablePath, password: serverPassword, portPolicy: portPolicy);

    try {
      final handle = await _supervisor.start(
        spec: spec,
        terminatedBridgeIdentities: terminatedBridgeIdentities.toList(growable: false),
      );
      Log.d("[OPENCODE] Started on port ${handle.port}");
      return _toRuntime(handle: handle, password: serverPassword);
    } on PluginStartException catch (error) {
      // Preserve the legacy failure type for expected start failures (health /
      // dynamic exhaustion / validation). A raw spawn error on the explicit
      // path propagates unwrapped, as it always has.
      throw OpenCodeServerStartException(error.message, cause: error.cause);
    }
  }

  Future<void> cleanupStaleOwnedServers({
    required Iterable<ProcessIdentity> terminatedBridgeIdentities,
  }) {
    return _supervisor.cleanupStaleOwnedRuntimes(
      terminatedBridgeIdentities: terminatedBridgeIdentities.toList(growable: false),
    );
  }

  Future<void> stopOwnedServer({required OpenCodeOwnershipRecord record}) {
    return _supervisor.stopOwnedRuntime(record: record);
  }

  Future<OpenCodeServerRuntime> validateExistingServer({
    required int port,
    required String? password,
  }) async {
    final probePassword = password == null || password.isEmpty ? "" : password;
    // Attach mode only ever uses the spec's health probe; the spawn / record /
    // port seams are inert here, so an unused explicit port policy is fine.
    final spec = _buildSpec(executablePath: "", password: probePassword, portPolicy: ExplicitPortPolicy(port: port));

    try {
      await _supervisor.attach(spec: spec, port: port);
    } on PluginStartException catch (error) {
      throw OpenCodeServerStartException(error.message, cause: error.cause);
    }

    return OpenCodeServerRuntime(
      serverUri: Uri.parse("http://$loopbackPortHost:$port"),
      serverPassword: password == null || password.isEmpty ? null : password,
      process: null,
      port: port,
      identity: null,
    );
  }

  ManagedRuntimeSpec<OpenCodeOwnershipRecord> _buildSpec({
    required String executablePath,
    required String password,
    required RuntimePortPolicy portPolicy,
  }) {
    return ManagedRuntimeSpec<OpenCodeOwnershipRecord>(
      spawn: ({required int port}) => _spawn(executablePath: executablePath, port: port, password: password),
      probeHealth: ({required int port}) => _probeHealth(port: port, password: password),
      probePortBindable: _probePortBindable,
      buildRecord: _buildRecord,
      portPolicy: portPolicy,
      // Legacy pacing: up to five probes, each preceded by a 500 ms delay.
      healthPolicy: const RuntimeHealthPolicy.attemptCount(attempts: 5, delay: Duration(milliseconds: 500)),
    );
  }

  Future<SpawnedProcess> _spawn({
    required String executablePath,
    required int port,
    required String password,
  }) async {
    final startResult = await _openCodeProcessRepository.startProcess(
      executablePath: executablePath,
      port: port,
      password: password,
    );
    final identity = await _resolveSpawnedIdentity(startIdentity: startResult.identity);
    return SpawnedOpenCodeProcess(process: startResult.process, identity: identity);
  }

  Future<RuntimeHealthProbe> _probeHealth({required int port, required String password}) async {
    final serverUri = Uri.parse("http://$loopbackPortHost:$port");
    final probe = await _openCodeProcessRepository.probeHealth(serverUri: serverUri, password: password);
    return RuntimeHealthProbe(healthy: probe.isHealthy, error: probe.error);
  }

  Future<bool> _probePortBindable({required int port}) async {
    final fact = await _portRepository.getAvailabilityFact(port: port);
    return fact.isAvailable;
  }

  OpenCodeOwnershipRecord _buildRecord(RuntimeRecordDraft draft) {
    return OpenCodeOwnershipRecord(
      ownerSessionId: draft.ownerSessionId,
      openCodePid: draft.runtimeIdentity.pid,
      openCodeStartMarker: draft.runtimeIdentity.startMarker,
      openCodeExecutablePath: draft.runtimeIdentity.executablePath ?? "",
      openCodeCommand: draft.runtimeIdentity.executablePath ?? "opencode",
      openCodeArgs: <String>["serve", "--port", "${draft.port}", "--hostname", loopbackPortHost],
      port: draft.port,
      bridgePid: draft.bridgeIdentity.pid,
      bridgeStartMarker: draft.bridgeIdentity.startMarker,
      startedAt: draft.startedAt,
      status: OpenCodeOwnershipStatus.starting,
    );
  }

  OpenCodeServerRuntime _toRuntime({
    required ManagedRuntimeHandle<OpenCodeOwnershipRecord> handle,
    required String password,
  }) {
    final spawned = handle.process;
    return OpenCodeServerRuntime(
      serverUri: Uri.parse("http://$loopbackPortHost:${handle.port}"),
      serverPassword: password,
      // The supervisor tracks our own SpawnedOpenCodeProcess, so the raw
      // dart:io process is always recoverable for the public runtime.
      process: spawned == null ? null : (spawned as SpawnedOpenCodeProcess).rawProcess,
      port: handle.port,
      identity: handle.identity,
    );
  }

  Future<ProcessIdentity> _resolveSpawnedIdentity({required ProcessIdentity startIdentity}) async {
    final inspectedIdentity = await _processRepository.inspectProcess(pid: startIdentity.pid);
    if (inspectedIdentity != null &&
        _matchesSpawnedIdentity(startIdentity: startIdentity, inspectedIdentity: inspectedIdentity)) {
      return inspectedIdentity;
    }
    return startIdentity;
  }

  bool _matchesSpawnedIdentity({
    required ProcessIdentity startIdentity,
    required ProcessIdentity inspectedIdentity,
  }) {
    if (inspectedIdentity.pid != startIdentity.pid) {
      return false;
    }

    if (Platform.isWindows && _isWindowsImageNameOnlyCommandLine(inspectedIdentity.commandLine)) {
      return _samePath(inspectedIdentity.executablePath, startIdentity.executablePath ?? "");
    }

    return inspectedIdentity.commandLine == startIdentity.commandLine;
  }

  bool _samePath(String? actual, String expected) {
    if (actual == null) {
      return false;
    }

    if (Platform.isWindows) {
      final normalizedActual = _normalizeWindowsPath(actual);
      final normalizedExpected = _normalizeWindowsPath(expected);
      if (normalizedActual == normalizedExpected) {
        return true;
      }

      return _windowsPathBasename(normalizedActual) == _windowsPathBasename(normalizedExpected);
    }

    return actual == expected;
  }

  bool _isWindowsImageNameOnlyCommandLine(String commandLine) {
    return commandLine.isNotEmpty && !commandLine.contains(" ") && !commandLine.contains("\t");
  }

  String _normalizeWindowsPath(String path) {
    var normalized = path.replaceAll("/", String.fromCharCode(92));
    if (normalized.toLowerCase().endsWith(".exe")) {
      normalized = normalized.substring(0, normalized.length - 4);
    }
    return normalized.toLowerCase();
  }

  String _windowsPathBasename(String path) {
    final segments = path.split(RegExp(r"[\\/]+"));
    return segments.isEmpty ? path : segments.last;
  }

  Iterable<int> _dynamicCandidates() sync* {
    final suppliedCandidates = _candidatePorts;
    if (suppliedCandidates != null) {
      for (final port in suppliedCandidates) {
        if (_isDynamicCandidate(port: port)) {
          yield port;
        }
      }
      return;
    }

    final seen = <int>{};
    while (seen.length < dynamicOpenCodeMaxAttempts) {
      final port = dynamicOpenCodePortMin + _random.nextInt(dynamicOpenCodePortMax - dynamicOpenCodePortMin + 1);
      if (_isDynamicCandidate(port: port) && seen.add(port)) {
        yield port;
      }
    }
  }

  bool _isDynamicCandidate({required int port}) {
    return port != openCodeDefaultPort && port >= dynamicOpenCodePortMin && port <= dynamicOpenCodePortMax;
  }
}

class OpenCodeServerRuntime {
  const OpenCodeServerRuntime({
    required this.serverUri,
    required this.serverPassword,
    required this.process,
    required this.port,
    required this.identity,
  });

  final Uri serverUri;
  final String? serverPassword;
  final Process? process;
  final int port;
  final ProcessIdentity? identity;
}

class OpenCodeServerStartException implements Exception {
  const OpenCodeServerStartException(this.message, {required this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() {
    if (cause == null) {
      return message;
    }
    return "$message Cause: $cause";
  }
}
