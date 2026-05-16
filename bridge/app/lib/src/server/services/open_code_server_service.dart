import "dart:io";
import "dart:math";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../foundation/process_identity.dart";
import "../foundation/process_match.dart";
import "../foundation/server_clock.dart";
import "../models/open_code_ownership_record.dart";
import "../repositories/open_code_ownership_repository.dart";
import "../repositories/open_code_process_repository.dart";
import "../repositories/port_repository.dart";
import "../repositories/process_repository.dart";

const int openCodeDefaultPort = 4096;
const int dynamicOpenCodePortMin = 49152;
const int dynamicOpenCodePortMax = 65535;
const int dynamicOpenCodeMaxAttempts = 5;
const Duration openCodeGracefulShutdownWait = Duration(seconds: 5);

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
       _ownershipRepository = ownershipRepository,
       _clock = clock,
       _currentBridgeIdentity = currentBridgeIdentity,
       _ownerSessionId = ownerSessionId,
       _candidatePorts = candidatePorts == null ? null : List<int>.from(candidatePorts),
       _random = random ?? Random.secure();

  final OpenCodeProcessRepository _openCodeProcessRepository;
  final ProcessRepository _processRepository;
  final PortRepository _portRepository;
  final OpenCodeOwnershipRepository _ownershipRepository;
  final ServerClock _clock;
  final ProcessIdentity _currentBridgeIdentity;
  final String _ownerSessionId;
  final List<int>? _candidatePorts;
  final Random _random;
  final Map<String, _CurrentOwnedOpenCodeProcess> _currentOwnedProcessesBySessionId =
      <String, _CurrentOwnedOpenCodeProcess>{};

  Future<OpenCodeServerRuntime> start({
    required String executablePath,
    required int? requestedPort,
    required String? password,
    required Iterable<ProcessIdentity> terminatedBridgeIdentities,
  }) async {
    await cleanupStaleOwnedServers(
      terminatedBridgeIdentities: terminatedBridgeIdentities,
    );

    final serverPassword = password == null || password.isEmpty
        ? _openCodeProcessRepository.generatePassword()
        : password;
    if (requestedPort != null) {
      Log.d("[OPENCODE] Starting on port $requestedPort");

      return _startOnExplicitPort(
        executablePath: executablePath,
        port: requestedPort,
        password: serverPassword,
      );
    } else {
      Log.d("[OPENCODE] Starting on dynamic port");
      return _startOnDynamicPort(
        executablePath: executablePath,
        password: serverPassword,
      );
    }
  }

  Future<void> cleanupStaleOwnedServers({
    required Iterable<ProcessIdentity> terminatedBridgeIdentities,
  }) async {
    final records = await _ownershipRepository.readAll();
    for (final record in records) {
      if (!await _isStaleKillAuthorized(
        record: record,
        terminatedBridgeIdentities: terminatedBridgeIdentities,
      )) {
        continue;
      }

      await _stopRecord(record: record, removeOwnership: true);
    }
  }

  Future<void> stopOwnedServer({required OpenCodeOwnershipRecord record}) async {
    await _ownershipRepository.upsert(
      record: _copyRecord(record: record, status: OpenCodeOwnershipStatus.stopping),
    );
    await _stopRecord(record: record, removeOwnership: true);
  }

  Future<OpenCodeServerRuntime> validateExistingServer({
    required int port,
    required String? password,
  }) async {
    final serverPassword = password == null || password.isEmpty ? "" : password;
    final serverUri = Uri.parse("http://$loopbackPortHost:$port");
    final probe = await _openCodeProcessRepository.probeHealth(
      serverUri: serverUri,
      password: serverPassword,
    );
    if (!probe.isHealthy) {
      throw OpenCodeServerStartException(
        "existing opencode server health check failed on port $port.",
        cause: probe.error,
      );
    }

    return OpenCodeServerRuntime(
      serverUri: serverUri,
      serverPassword: password == null || password.isEmpty ? null : password,
      process: null,
      port: port,
      identity: null,
    );
  }

  Future<OpenCodeServerRuntime> _startOnExplicitPort({
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
    final record = await _writeStartingRecord(
      port: port,
      startResult: startResult,
      identity: identity,
    );

    try {
      return await _confirmHealthyRuntime(
        port: port,
        password: password,
        startResult: startResult,
        identity: identity,
        record: record,
      );
    } on Object {
      await _cleanupFailedStart(record: record);
      rethrow;
    }
  }

  Future<OpenCodeServerRuntime> _startOnDynamicPort({
    required String executablePath,
    required String password,
  }) async {
    Object? lastError;
    var attempts = 0;

    for (final port in _dynamicCandidates()) {
      if (attempts >= dynamicOpenCodeMaxAttempts) {
        break;
      }
      attempts += 1;

      final fact = await _portRepository.getAvailabilityFact(port: port);
      if (!fact.isAvailable) {
        continue;
      }

      OpenCodeOwnershipRecord? record;
      try {
        Log.d("[OPENCODE] Found available port $port. Attempting to start");
        final startResult = await _openCodeProcessRepository.startProcess(
          executablePath: executablePath,
          port: port,
          password: password,
        );
        final identity = await _resolveSpawnedIdentity(startIdentity: startResult.identity);
        record = await _writeStartingRecord(
          port: port,
          startResult: startResult,
          identity: identity,
        );

        Log.d("[OPENCODE] Started on port $port. Preparing alive check");
        const maxAttempts = 5;
        for (int i = 1; i <= maxAttempts; i++) {
          await _clock.delay(duration: const Duration(milliseconds: 500));
          try {
            return await _confirmHealthyRuntime(
              port: port,
              password: password,
              startResult: startResult,
              identity: identity,
              record: record,
            );
          } catch (err) {
            // no-op
          }

          Log.d("[OPENCODE] Alive check attempt $i/$maxAttempts FAILED.${i < maxAttempts ? " Retrying..." : ""}");
        }
        throw Exception("[OPENCODE] All attempts failed");
      } on Object catch (error) {
        Log.e("[OPENCODE] Failed to start on port $port. $error");
        lastError = error;
        if (record != null) {
          await _cleanupFailedStart(record: record);
        }
      }
    }

    throw OpenCodeServerStartException(
      "Unable to start opencode on an available dynamic port after $attempts attempts.",
      cause: lastError,
    );
  }

  Future<OpenCodeOwnershipRecord> _writeStartingRecord({
    required int port,
    required OpenCodeStartResult startResult,
    required ProcessIdentity identity,
  }) async {
    final record = OpenCodeOwnershipRecord(
      ownerSessionId: _ownerSessionId,
      openCodePid: identity.pid,
      openCodeStartMarker: identity.startMarker,
      openCodeExecutablePath: identity.executablePath ?? "",
      openCodeCommand: identity.executablePath ?? "opencode",
      openCodeArgs: <String>["serve", "--port", "$port", "--hostname", loopbackPortHost],
      port: port,
      bridgePid: _currentBridgeIdentity.pid,
      bridgeStartMarker: _currentBridgeIdentity.startMarker,
      startedAt: _clock.now(),
      status: OpenCodeOwnershipStatus.starting,
    );
    await _ownershipRepository.upsert(record: record);
    _currentOwnedProcessesBySessionId[record.ownerSessionId] = _CurrentOwnedOpenCodeProcess(
      process: startResult.process,
      identity: identity,
    );
    return record;
  }

  Future<OpenCodeServerRuntime> _confirmHealthyRuntime({
    required int port,
    required String password,
    required OpenCodeStartResult startResult,
    required ProcessIdentity identity,
    required OpenCodeOwnershipRecord record,
  }) async {
    final serverUri = Uri.parse("http://$loopbackPortHost:$port");
    final probe = await _openCodeProcessRepository.probeHealth(
      serverUri: serverUri,
      password: password,
    );
    if (!probe.isHealthy) {
      throw OpenCodeServerStartException(
        "opencode health check failed on port $port.",
        cause: probe.error,
      );
    }

    await _ownershipRepository.upsert(
      record: _copyRecord(record: record, status: OpenCodeOwnershipStatus.ready),
    );
    return OpenCodeServerRuntime(
      serverUri: serverUri,
      serverPassword: password,
      process: startResult.process,
      port: port,
      identity: identity,
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
    return inspectedIdentity.pid == startIdentity.pid && inspectedIdentity.commandLine == startIdentity.commandLine;
  }

  Future<void> _cleanupFailedStart({required OpenCodeOwnershipRecord record}) async {
    await _stopRecord(record: record, removeOwnership: true);
  }

  Future<void> _stopRecord({
    required OpenCodeOwnershipRecord record,
    required bool removeOwnership,
  }) async {
    final currentOwnedProcess = _currentOwnedProcessFor(record: record);
    final initialIdentity = await _processRepository.inspectProcess(pid: record.openCodePid);
    final matchesInitialIdentity =
        initialIdentity != null && _matchesOpenCodeRecord(identity: initialIdentity, record: record);
    if (!matchesInitialIdentity && currentOwnedProcess == null) {
      if (removeOwnership) {
        await _ownershipRepository.deleteByOwnerSessionId(ownerSessionId: record.ownerSessionId);
      }
      return;
    }

    if (!matchesInitialIdentity && currentOwnedProcess != null) {
      final currentOwnedStillRunningBeforeGraceful = await _isCurrentOwnedProcessRunning(process: currentOwnedProcess);
      if (!currentOwnedStillRunningBeforeGraceful) {
        _currentOwnedProcessesBySessionId.remove(record.ownerSessionId);
        if (removeOwnership) {
          await _ownershipRepository.deleteByOwnerSessionId(ownerSessionId: record.ownerSessionId);
        }
        return;
      }
    }

    await _processRepository.sendGracefulSignal(pid: record.openCodePid);
    await _clock.delay(duration: openCodeGracefulShutdownWait);

    final currentOwnedStillRunningAfterGraceful =
        currentOwnedProcess != null && await _isCurrentOwnedProcessRunning(process: currentOwnedProcess);
    final remainingIdentity = await _processRepository.inspectProcess(pid: record.openCodePid);
    final matchesRemainingIdentity =
        remainingIdentity != null && _matchesOpenCodeRecord(identity: remainingIdentity, record: record);
    if (currentOwnedStillRunningAfterGraceful || matchesRemainingIdentity) {
      await _processRepository.sendForceSignal(pid: record.openCodePid);
    }

    final finalIdentity = await _processRepository.inspectProcess(pid: record.openCodePid);
    final currentOwnedStillRunningAfterForce =
        currentOwnedProcess != null && await _isCurrentOwnedProcessRunning(process: currentOwnedProcess);
    if (!currentOwnedStillRunningAfterForce) {
      _currentOwnedProcessesBySessionId.remove(record.ownerSessionId);
    }
    if (currentOwnedStillRunningAfterForce) {
      return;
    }

    if (finalIdentity == null || !_matchesOpenCodeRecord(identity: finalIdentity, record: record)) {
      if (removeOwnership) {
        await _ownershipRepository.deleteByOwnerSessionId(ownerSessionId: record.ownerSessionId);
      }
    }
  }

  _CurrentOwnedOpenCodeProcess? _currentOwnedProcessFor({required OpenCodeOwnershipRecord record}) {
    final currentOwnedProcess = _currentOwnedProcessesBySessionId[record.ownerSessionId];
    if (currentOwnedProcess == null || !_matchesCurrentOwnedRecord(process: currentOwnedProcess, record: record)) {
      return null;
    }
    return currentOwnedProcess;
  }

  bool _matchesCurrentOwnedRecord({
    required _CurrentOwnedOpenCodeProcess process,
    required OpenCodeOwnershipRecord record,
  }) {
    return process.identity.pid == record.openCodePid &&
        (record.openCodeStartMarker == null || process.identity.startMarker == record.openCodeStartMarker) &&
        _samePath(process.identity.executablePath, record.openCodeExecutablePath) &&
        process.identity.commandLine == [record.openCodeCommand, ...record.openCodeArgs].join(" ");
  }

  Future<bool> _isCurrentOwnedProcessRunning({required _CurrentOwnedOpenCodeProcess process}) async {
    final exitCode = await process.process.exitCode
        .then<int?>((int code) => code)
        .timeout(
          Duration.zero,
          onTimeout: () => null,
        );
    return exitCode == null;
  }

  Future<bool> _isStaleKillAuthorized({
    required OpenCodeOwnershipRecord record,
    required Iterable<ProcessIdentity> terminatedBridgeIdentities,
  }) async {
    if (record.openCodeStartMarker == null) {
      return false;
    }

    final openCodeIdentity = await _processRepository.inspectProcess(pid: record.openCodePid);
    if (openCodeIdentity == null || !_matchesOpenCodeRecord(identity: openCodeIdentity, record: record)) {
      await _ownershipRepository.deleteByOwnerSessionId(ownerSessionId: record.ownerSessionId);
      return false;
    }

    if (_matchesBridgeRecord(identity: _currentBridgeIdentity, record: record)) {
      return true;
    }

    for (final identity in terminatedBridgeIdentities) {
      if (_matchesBridgeRecord(identity: identity, record: record)) {
        return true;
      }
    }

    final ownerBridge = await _processRepository.inspectProcessMatch(pid: record.bridgePid);
    if (ownerBridge != null &&
        ownerBridge.kind == ProcessMatchKind.sesoriBridge &&
        _matchesBridgeRecord(identity: ownerBridge.identity, record: record)) {
      return false;
    }

    return true;
  }

  bool _matchesOpenCodeRecord({
    required ProcessIdentity identity,
    required OpenCodeOwnershipRecord record,
  }) {
    return identity.pid == record.openCodePid &&
        identity.startMarker != null &&
        identity.startMarker == record.openCodeStartMarker &&
        _samePath(identity.executablePath, record.openCodeExecutablePath) &&
        identity.commandLine == [record.openCodeCommand, ...record.openCodeArgs].join(" ");
  }

  bool _matchesBridgeRecord({
    required ProcessIdentity identity,
    required OpenCodeOwnershipRecord record,
  }) {
    return identity.pid == record.bridgePid &&
        record.bridgeStartMarker != null &&
        identity.startMarker == record.bridgeStartMarker;
  }

  bool _samePath(String? actual, String expected) {
    return actual != null && actual == expected;
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

  OpenCodeOwnershipRecord _copyRecord({
    required OpenCodeOwnershipRecord record,
    required OpenCodeOwnershipStatus status,
  }) {
    return OpenCodeOwnershipRecord(
      ownerSessionId: record.ownerSessionId,
      openCodePid: record.openCodePid,
      openCodeStartMarker: record.openCodeStartMarker,
      openCodeExecutablePath: record.openCodeExecutablePath,
      openCodeCommand: record.openCodeCommand,
      openCodeArgs: record.openCodeArgs,
      port: record.port,
      bridgePid: record.bridgePid,
      bridgeStartMarker: record.bridgeStartMarker,
      startedAt: record.startedAt,
      status: status,
    );
  }
}

class _CurrentOwnedOpenCodeProcess {
  const _CurrentOwnedOpenCodeProcess({
    required this.process,
    required this.identity,
  });

  final Process process;
  final ProcessIdentity identity;
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
