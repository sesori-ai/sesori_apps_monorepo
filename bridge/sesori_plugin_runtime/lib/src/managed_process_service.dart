import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "runtime_ownership_repository.dart";
import "runtime_record_mapper.dart";

class ManagedProcessService<R> {
  ManagedProcessService({
    required RuntimeOwnershipRepository<R> ownershipRepository,
    required RuntimeRecordMapper<R> mapper,
    required HostProcessService processes,
    required BridgeHostInfo bridge,
    required ServerClock clock,
    required String runtimeId,
    required Duration gracefulShutdownWait,
  }) : _ownershipRepository = ownershipRepository,
       _mapper = mapper,
       _processes = processes,
       _bridge = bridge,
       _clock = clock,
       _runtimeId = runtimeId,
       _gracefulShutdownWait = gracefulShutdownWait;

  final RuntimeOwnershipRepository<R> _ownershipRepository;
  final RuntimeRecordMapper<R> _mapper;
  final HostProcessService _processes;
  final BridgeHostInfo _bridge;
  final ServerClock _clock;
  final String _runtimeId;
  final Duration _gracefulShutdownWait;
  final Map<String, _CurrentOwnedRuntimeProcess> _currentOwnedProcessesBySessionId =
      <String, _CurrentOwnedRuntimeProcess>{};

  void trackOwnedRuntime({required String ownerSessionId, required SpawnedProcess process}) {
    _currentOwnedProcessesBySessionId[ownerSessionId] = _CurrentOwnedRuntimeProcess(
      process: process,
      identity: process.identity,
    );
  }

  bool isTrackingOwnedRuntime({required String ownerSessionId}) {
    return _currentOwnedProcessesBySessionId.containsKey(ownerSessionId);
  }

  Future<void> cleanupStaleOwnedRuntimes({required List<ProcessIdentity> terminatedBridgeIdentities}) async {
    final records = await _ownershipRepository.readAll();

    final recordsToTerminate = <R>[];
    for (final record in records) {
      if (!await _isStaleKillAuthorized(record: record, terminatedBridgeIdentities: terminatedBridgeIdentities)) {
        continue;
      }

      final shouldTerminate = await _shouldTerminateRecord(record: record);
      if (shouldTerminate) {
        recordsToTerminate.add(record);
      }
    }

    if (recordsToTerminate.isEmpty) {
      return;
    }

    try {
      await Future.wait(
        recordsToTerminate.map(
          (record) => Future.sync(() => _processes.signalGraceful(pid: _runtimePidOf(record: record))),
        ),
      ).timeout(_gracefulShutdownWait);
    } catch (error, stackTrace) {
      Log.w("[$_runtimeId] Failed to gracefully stop some runtime instance(s)", error, stackTrace);
    }

    await _clock.delay(duration: _gracefulShutdownWait);

    final survivors = <R>[];
    for (final record in recordsToTerminate) {
      final currentOwned = _currentOwnedProcessFor(record: record);
      final currentOwnedStillRunning =
          currentOwned != null && await _isCurrentOwnedProcessRunning(process: currentOwned);
      final remainingIdentity = await _processes.inspect(pid: _runtimePidOf(record: record));
      final matchesRemaining =
          remainingIdentity != null && _matchesRuntimeRecord(identity: remainingIdentity, record: record);

      if (currentOwnedStillRunning || matchesRemaining) {
        survivors.add(record);
      } else {
        _currentOwnedProcessesBySessionId.remove(_ownerSessionIdOf(record: record));
      }
    }

    try {
      await Future.wait(
        survivors.map(
          (record) => Future.sync(() => _processes.signalForce(pid: _runtimePidOf(record: record))),
        ),
      ).timeout(_gracefulShutdownWait);
    } catch (error, stackTrace) {
      Log.w("[$_runtimeId] Failed to force kill some runtime instance(s)", error, stackTrace);
    }

    for (final record in recordsToTerminate) {
      final currentOwned = _currentOwnedProcessFor(record: record);
      final currentOwnedStillRunning =
          currentOwned != null && await _isCurrentOwnedProcessRunning(process: currentOwned);

      if (!currentOwnedStillRunning) {
        _currentOwnedProcessesBySessionId.remove(_ownerSessionIdOf(record: record));
      }

      if (currentOwnedStillRunning) {
        continue;
      }

      final finalIdentity = await _processes.inspect(pid: _runtimePidOf(record: record));
      if (finalIdentity == null || !_matchesRuntimeRecord(identity: finalIdentity, record: record)) {
        await _ownershipRepository.deleteByOwnerSessionId(ownerSessionId: _ownerSessionIdOf(record: record));
      }
    }
  }

  Future<void> stopOwnedRuntime({required R record}) async {
    await _ownershipRepository.upsert(record: _mapper.markStopping(record: record));
    await _stopRecord(record: record, removeOwnership: true);
  }

  Future<void> _stopRecord({required R record, required bool removeOwnership}) async {
    final currentOwnedProcess = _currentOwnedProcessFor(record: record);
    final initialIdentity = await _processes.inspect(pid: _runtimePidOf(record: record));
    final matchesInitialIdentity =
        initialIdentity != null && _matchesRuntimeRecord(identity: initialIdentity, record: record);
    if (!matchesInitialIdentity && currentOwnedProcess == null) {
      if (removeOwnership) {
        await _ownershipRepository.deleteByOwnerSessionId(ownerSessionId: _ownerSessionIdOf(record: record));
      }
      return;
    }

    if (!matchesInitialIdentity && currentOwnedProcess != null) {
      final currentOwnedStillRunningBeforeGraceful = await _isCurrentOwnedProcessRunning(process: currentOwnedProcess);
      if (!currentOwnedStillRunningBeforeGraceful) {
        _currentOwnedProcessesBySessionId.remove(_ownerSessionIdOf(record: record));
        if (removeOwnership) {
          await _ownershipRepository.deleteByOwnerSessionId(ownerSessionId: _ownerSessionIdOf(record: record));
        }
        return;
      }
    }

    await _processes.signalGraceful(pid: _runtimePidOf(record: record));
    await _clock.delay(duration: _gracefulShutdownWait);

    final currentOwnedStillRunningAfterGraceful =
        currentOwnedProcess != null && await _isCurrentOwnedProcessRunning(process: currentOwnedProcess);
    final remainingIdentity = await _processes.inspect(pid: _runtimePidOf(record: record));
    final matchesRemainingIdentity =
        remainingIdentity != null && _matchesRuntimeRecord(identity: remainingIdentity, record: record);
    if (currentOwnedStillRunningAfterGraceful || matchesRemainingIdentity) {
      await _processes.signalForce(pid: _runtimePidOf(record: record));
    }

    final finalIdentity = await _processes.inspect(pid: _runtimePidOf(record: record));
    final currentOwnedStillRunningAfterForce =
        currentOwnedProcess != null && await _isCurrentOwnedProcessRunning(process: currentOwnedProcess);
    if (!currentOwnedStillRunningAfterForce) {
      _currentOwnedProcessesBySessionId.remove(_ownerSessionIdOf(record: record));
    }
    if (currentOwnedStillRunningAfterForce) {
      return;
    }

    if (finalIdentity == null || !_matchesRuntimeRecord(identity: finalIdentity, record: record)) {
      if (removeOwnership) {
        await _ownershipRepository.deleteByOwnerSessionId(ownerSessionId: _ownerSessionIdOf(record: record));
      }
    }
  }

  Future<bool> _shouldTerminateRecord({required R record}) async {
    final currentOwnedProcess = _currentOwnedProcessFor(record: record);
    final initialIdentity = await _processes.inspect(pid: _runtimePidOf(record: record));
    final matchesInitialIdentity =
        initialIdentity != null && _matchesRuntimeRecord(identity: initialIdentity, record: record);

    if (!matchesInitialIdentity && currentOwnedProcess == null) {
      await _ownershipRepository.deleteByOwnerSessionId(ownerSessionId: _ownerSessionIdOf(record: record));
      return false;
    }

    if (!matchesInitialIdentity && currentOwnedProcess != null) {
      final currentOwnedStillRunningBeforeGraceful = await _isCurrentOwnedProcessRunning(process: currentOwnedProcess);
      if (!currentOwnedStillRunningBeforeGraceful) {
        _currentOwnedProcessesBySessionId.remove(_ownerSessionIdOf(record: record));
        await _ownershipRepository.deleteByOwnerSessionId(ownerSessionId: _ownerSessionIdOf(record: record));
        return false;
      }
    }

    return true;
  }

  _CurrentOwnedRuntimeProcess? _currentOwnedProcessFor({required R record}) {
    final currentOwnedProcess = _currentOwnedProcessesBySessionId[_ownerSessionIdOf(record: record)];
    if (currentOwnedProcess == null || !_matchesCurrentOwnedRecord(process: currentOwnedProcess, record: record)) {
      return null;
    }
    return currentOwnedProcess;
  }

  bool _matchesCurrentOwnedRecord({required _CurrentOwnedRuntimeProcess process, required R record}) {
    return process.identity.pid == _runtimePidOf(record: record) &&
        (_runtimeStartMarkerOf(record: record) == null ||
            process.identity.startMarker == _runtimeStartMarkerOf(record: record)) &&
        _samePath(
          process.identity.executablePath,
          _runtimeExecutablePathOf(record: record),
          platform: process.identity.platform,
        ) &&
        _matchesRuntimeCommandLine(identity: process.identity, record: record);
  }

  Future<bool> _isCurrentOwnedProcessRunning({required _CurrentOwnedRuntimeProcess process}) async {
    final exitCode = await process.process.exitCode
        .then<int?>((code) => code)
        .timeout(Duration.zero, onTimeout: () => null);
    return exitCode == null;
  }

  Future<bool> _isStaleKillAuthorized({
    required R record,
    required Iterable<ProcessIdentity> terminatedBridgeIdentities,
  }) async {
    final runtimeIdentity = await _processes.inspect(pid: _runtimePidOf(record: record));
    if (runtimeIdentity == null || !_matchesRuntimeRecord(identity: runtimeIdentity, record: record)) {
      await _ownershipRepository.deleteByOwnerSessionId(ownerSessionId: _ownerSessionIdOf(record: record));
      return false;
    }

    if (_matchesBridgeRecord(identity: _bridge.identity, record: record)) {
      return true;
    }

    for (final identity in terminatedBridgeIdentities) {
      if (_matchesBridgeRecord(identity: identity, record: record)) {
        return true;
      }
    }

    final ownerBridgeIsLive = await _bridge.isLiveBridgeProcess(
      pid: _bridgePidOf(record: record),
      startMarker: _bridgeStartMarkerOf(record: record),
    );
    if (ownerBridgeIsLive) {
      return false;
    }

    return true;
  }

  bool _matchesRuntimeRecord({required ProcessIdentity identity, required R record}) {
    if (identity.pid != _runtimePidOf(record: record)) {
      return false;
    }
    if (_runtimeStartMarkerOf(record: record) != null || identity.startMarker != null) {
      return identity.startMarker == _runtimeStartMarkerOf(record: record) &&
          _samePath(identity.executablePath, _runtimeExecutablePathOf(record: record), platform: identity.platform) &&
          _matchesRuntimeCommandLine(identity: identity, record: record);
    }
    return _samePath(identity.executablePath, _runtimeExecutablePathOf(record: record), platform: identity.platform);
  }

  bool _matchesBridgeRecord({required ProcessIdentity identity, required R record}) {
    if (identity.pid != _bridgePidOf(record: record)) {
      return false;
    }
    if (_bridgeStartMarkerOf(record: record) != null || identity.startMarker != null) {
      return identity.startMarker == _bridgeStartMarkerOf(record: record);
    }
    return true;
  }

  bool _samePath(String? actual, String? expected, {required String platform}) {
    if (actual == null || expected == null) {
      return false;
    }

    if (!_isWindowsPlatform(platform: platform)) {
      return actual == expected;
    }

    final normalizedActual = _normalizeWindowsPath(actual);
    final normalizedExpected = _normalizeWindowsPath(expected);
    if (normalizedActual == normalizedExpected) {
      return true;
    }

    return _windowsPathBasename(normalizedActual) == _windowsPathBasename(normalizedExpected);
  }

  bool _isWindowsPlatform({required String platform}) {
    final normalizedPlatform = platform.toLowerCase();
    return normalizedPlatform == "windows" || normalizedPlatform == "win32";
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

  bool _matchesRuntimeCommandLine({required ProcessIdentity identity, required R record}) {
    return identity.commandLine == _mapper.runtimeCommandLineOf(record: record);
  }

  String _ownerSessionIdOf({required R record}) => _mapper.ownerSessionIdOf(record: record);

  int _runtimePidOf({required R record}) => _mapper.runtimePidOf(record: record);

  String? _runtimeStartMarkerOf({required R record}) => _mapper.runtimeStartMarkerOf(record: record);

  String? _runtimeExecutablePathOf({required R record}) => _mapper.runtimeExecutablePathOf(record: record);

  int _bridgePidOf({required R record}) => _mapper.bridgePidOf(record: record);

  String? _bridgeStartMarkerOf({required R record}) => _mapper.bridgeStartMarkerOf(record: record);
}

class _CurrentOwnedRuntimeProcess {
  const _CurrentOwnedRuntimeProcess({required this.process, required this.identity});

  final SpawnedProcess process;
  final ProcessIdentity identity;
}
