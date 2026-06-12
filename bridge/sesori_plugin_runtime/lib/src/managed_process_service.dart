import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "managed_runtime_spec.dart";
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

  /// Starts a freshly owned runtime per [spec], after first cleaning up any
  /// stale runtimes this bridge is authorized to reclaim.
  ///
  /// Honors the cooperative abort [startAborted] at every phase boundary: an
  /// aborted start rolls back everything it acquired (kills the child, deletes
  /// the record) and settles by throwing [PluginStartAbortedException] — never
  /// by abandonment, because the bridge holds its startup mutex until this
  /// settles. A spawn that cannot even launch propagates from the explicit
  /// path and is retried on the dynamic path; any other start failure rolls
  /// back and throws [PluginStartException].
  Future<ManagedRuntimeHandle<R>> start({
    required ManagedRuntimeSpec<R> spec,
    required List<ProcessIdentity> terminatedBridgeIdentities,
    StartAbortSignal? startAborted,
  }) async {
    final abort = startAborted ?? StartAbortSignal.never;

    // A deterministic configuration error: reject it once, up front, so the
    // dynamic path never retries it candidate by candidate.
    if (spec.recordTiming == RuntimeRecordTiming.intentSideFile) {
      // The bridge-private intent side file is introduced in a later step;
      // until then only the legacy after-spawn timing is representable.
      throw UnsupportedError("[$_runtimeId] intent side-file record timing is not available yet");
    }

    await cleanupStaleOwnedRuntimes(terminatedBridgeIdentities: terminatedBridgeIdentities);
    _throwIfAborted(abort);

    final portPolicy = spec.portPolicy;
    switch (portPolicy) {
      case ExplicitPortPolicy():
        return _startOnExplicitPort(spec: spec, policy: portPolicy, abort: abort);
      case DynamicPortPolicy():
        return _startOnDynamicPort(spec: spec, policy: portPolicy, abort: abort);
    }
  }

  /// Attaches to a runtime already listening on [port] (the `--no-auto-start`
  /// path): a single health probe, no ownership, no process to kill. Returns
  /// an un-owned handle on success; throws [PluginStartException] when the
  /// existing server is unreachable.
  Future<ManagedRuntimeHandle<R>> attach({
    required ManagedRuntimeSpec<R> spec,
    required int port,
    StartAbortSignal? startAborted,
  }) async {
    final abort = startAborted ?? StartAbortSignal.never;
    _throwIfAborted(abort);

    final probe = await _probeTolerant(spec: spec, port: port);
    // Honor an abort that fired while the probe was in flight: even a healthy
    // result must not produce a live handle once the bridge has aborted.
    _throwIfAborted(abort);
    if (!probe.healthy) {
      throw PluginStartException(
        "[$_runtimeId] existing runtime health check failed on port $port",
        cause: probe.error,
      );
    }

    return ManagedRuntimeHandle<R>(
      port: port,
      record: null,
      process: null,
      identity: null,
      health: probe,
    );
  }

  Future<ManagedRuntimeHandle<R>> _startOnExplicitPort({
    required ManagedRuntimeSpec<R> spec,
    required ExplicitPortPolicy policy,
    required StartAbortSignal abort,
  }) async {
    if (policy.preProbeBindable) {
      final bindable = await spec.probePortBindable(port: policy.port);
      if (!bindable) {
        throw PluginStartException(
          "[$_runtimeId] explicit port ${policy.port} is already in use",
          cause: null,
        );
      }
      _throwIfAborted(abort);
    }
    return _startAndConfirmHealthy(spec: spec, port: policy.port, abort: abort);
  }

  Future<ManagedRuntimeHandle<R>> _startOnDynamicPort({
    required ManagedRuntimeSpec<R> spec,
    required DynamicPortPolicy policy,
    required StartAbortSignal abort,
  }) async {
    Object? lastError;
    var attempts = 0;

    // The cap counts every raw candidate examined — not just the in-range
    // ones — so a lazy source that keeps yielding the reserved or out-of-range
    // port can never spin past maxAttempts while the startup mutex is held.
    for (final port in policy.candidates) {
      if (attempts >= policy.maxAttempts) {
        break;
      }
      attempts += 1;

      if (port == policy.reservedPort || port < policy.minPort || port > policy.maxPort) {
        continue;
      }

      _throwIfAborted(abort);

      final bindable = await spec.probePortBindable(port: port);
      if (!bindable) {
        continue;
      }

      try {
        return await _startAndConfirmHealthy(spec: spec, port: port, abort: abort);
      } on PluginStartAbortedException {
        rethrow;
      } on PluginStartException catch (error) {
        // A failure after a successful spawn (health/validation): try the
        // next candidate, as the legacy path does.
        lastError = error;
      } on Object catch (error) {
        // A spawn that could not launch: retry the next candidate unless the
        // policy opts into failing fast.
        if (policy.failFastOnSpawnError) {
          rethrow;
        }
        Log.w("[$_runtimeId] Failed to start runtime on port $port", error);
        lastError = error;
      }
    }

    throw PluginStartException(
      "[$_runtimeId] unable to start runtime on an available dynamic port after $attempts attempt(s)",
      cause: lastError,
    );
  }

  Future<ManagedRuntimeHandle<R>> _startAndConfirmHealthy({
    required ManagedRuntimeSpec<R> spec,
    required int port,
    required StartAbortSignal abort,
  }) async {
    // Spawn errors propagate before any ownership state is acquired: the
    // explicit-port caller surfaces them raw, the dynamic caller retries.
    final spawned = await spec.spawn(port: port);

    final R record;
    try {
      record = spec.buildRecord(
        RuntimeRecordDraft(
          ownerSessionId: _bridge.ownerSessionId,
          runtimeIdentity: spawned.identity,
          port: port,
          bridgeIdentity: _bridge.identity,
          startedAt: _clock.now(),
        ),
      );
    } on Object {
      // The child is already running but not yet tracked or recorded — stop it
      // directly so a record-factory failure cannot leak a started runtime.
      try {
        await _stopUntrackedSpawn(process: spawned);
      } on Object catch (cleanupError, cleanupStackTrace) {
        Log.w("[$_runtimeId] Failed to stop an orphaned child after a record build error on port $port", cleanupError, cleanupStackTrace);
      }
      rethrow;
    }
    trackOwnedRuntime(ownerSessionId: _ownerSessionIdOf(record: record), process: spawned);

    try {
      await _ownershipRepository.upsert(record: record);
      _throwIfAborted(abort);

      final health = await _confirmHealthy(spec: spec, port: port, spawned: spawned, abort: abort);

      final validate = spec.validateRuntime;
      if (validate != null) {
        try {
          await validate(port: port);
        } on PluginStartAbortedException {
          rethrow;
        } on Object catch (error) {
          // Surface validation failures as a (retryable) start failure rather
          // than a raw error the dynamic path would mistake for a spawn error.
          throw PluginStartException("[$_runtimeId] runtime validation failed on port $port", cause: error);
        }
      }
      _throwIfAborted(abort);

      final readyRecord = _mapper.markReady(record: record);
      await _ownershipRepository.upsert(record: readyRecord);

      return ManagedRuntimeHandle<R>(
        port: port,
        record: readyRecord,
        process: spawned,
        identity: spawned.identity,
        health: health,
      );
    } on Object {
      // Never let a cleanup failure mask the error that triggered it.
      try {
        await _cleanupFailedStart(record: record);
      } on Object catch (cleanupError, cleanupStackTrace) {
        Log.w("[$_runtimeId] Failed to clean up after a failed start on port $port", cleanupError, cleanupStackTrace);
      }
      rethrow;
    }
  }

  Future<RuntimeHealthProbe> _confirmHealthy({
    required ManagedRuntimeSpec<R> spec,
    required int port,
    required SpawnedProcess spawned,
    required StartAbortSignal abort,
  }) async {
    final policy = spec.healthPolicy;
    switch (policy) {
      case HealthAttemptCountPolicy():
        RuntimeHealthProbe? last;
        for (var attempt = 1; attempt <= policy.attempts; attempt += 1) {
          await _clock.delay(duration: policy.delay);
          final probe = await _probeOnce(spec: spec, port: port, spawned: spawned, abort: abort);
          last = probe;
          if (probe.healthy) {
            return probe;
          }
        }
        throw PluginStartException(
          "[$_runtimeId] health check failed on port $port after ${policy.attempts} attempt(s)",
          cause: last?.error,
        );
      case HealthDeadlinePolicy():
        final deadline = _clock.now().add(policy.deadline);
        RuntimeHealthProbe? last;
        while (true) {
          await _clock.delay(duration: policy.pollInterval);
          final probe = await _probeOnce(spec: spec, port: port, spawned: spawned, abort: abort);
          last = probe;
          if (probe.healthy) {
            return probe;
          }
          if (!_clock.now().isBefore(deadline)) {
            throw PluginStartException(
              "[$_runtimeId] health check failed on port $port within ${policy.deadline.inMilliseconds}ms",
              cause: last.error,
            );
          }
        }
    }
  }

  Future<RuntimeHealthProbe> _probeOnce({
    required ManagedRuntimeSpec<R> spec,
    required int port,
    required SpawnedProcess spawned,
    required StartAbortSignal abort,
  }) async {
    _throwIfAborted(abort);

    if (spec.failOnEarlyChildExit && await _spawnedProcessExited(process: spawned)) {
      // The child we launched is gone; a healthy probe now would be answered
      // by an unrelated process holding the port. Fail authoritatively.
      throw PluginStartException(
        "[$_runtimeId] runtime exited before becoming healthy on port $port",
        cause: null,
      );
    }

    return _probeTolerant(spec: spec, port: port);
  }

  /// Probes health, treating a thrown probe as unhealthy — the [ManagedRuntimeSpec.probeHealth]
  /// contract lets a transient connection error simply read as "not ready yet".
  Future<RuntimeHealthProbe> _probeTolerant({required ManagedRuntimeSpec<R> spec, required int port}) async {
    try {
      return await spec.probeHealth(port: port);
    } on Object catch (error) {
      return RuntimeHealthProbe.unhealthy(error: error);
    }
  }

  Future<bool> _spawnedProcessExited({required SpawnedProcess process}) async {
    final exitCode = await process.exitCode.then<int?>((code) => code).timeout(Duration.zero, onTimeout: () => null);
    return exitCode != null;
  }

  Future<void> _cleanupFailedStart({required R record}) async {
    await _stopRecord(record: record, removeOwnership: true);
  }

  /// Stops a freshly spawned child that has no ownership record yet (the record
  /// factory threw before one could be built). Graceful, then force if it
  /// outlives the grace period — there is nothing tracked or persisted to undo.
  Future<void> _stopUntrackedSpawn({required SpawnedProcess process}) async {
    if (await _spawnedProcessExited(process: process)) {
      return;
    }
    await _processes.signalGraceful(pid: process.pid);
    await _clock.delay(duration: _gracefulShutdownWait);
    if (!await _spawnedProcessExited(process: process)) {
      await _processes.signalForce(pid: process.pid);
    }
  }

  void _throwIfAborted(StartAbortSignal abort) {
    if (abort.isAborted) {
      throw const PluginStartAbortedException();
    }
  }

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
