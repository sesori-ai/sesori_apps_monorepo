import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "managed_runtime_spec.dart";
import "runtime_ownership_repository.dart";
import "runtime_record_mapper.dart";
import "runtime_start_intent.dart";

class ManagedProcessService<R> {
  ManagedProcessService({
    required RuntimeOwnershipRepository<R> ownershipRepository,
    required RuntimeRecordMapper<R> mapper,
    required HostProcessService processes,
    required BridgeHostInfo bridge,
    required ServerClock clock,
    required String runtimeId,
    required Duration gracefulShutdownWait,
    RuntimeStartIntentStore? intentStore,
  }) : _ownershipRepository = ownershipRepository,
       _mapper = mapper,
       _processes = processes,
       _bridge = bridge,
       _clock = clock,
       _runtimeId = runtimeId,
       _gracefulShutdownWait = gracefulShutdownWait,
       _intentStore = intentStore;

  final RuntimeOwnershipRepository<R> _ownershipRepository;
  final RuntimeRecordMapper<R> _mapper;
  final HostProcessService _processes;
  final BridgeHostInfo _bridge;
  final ServerClock _clock;
  final String _runtimeId;
  final Duration _gracefulShutdownWait;

  /// Optional bridge-private side-file store for [RuntimeRecordTiming.intentSideFile].
  /// Required when that timing is selected; unused for the legacy after-spawn
  /// timing, so it defaults to null and the legacy path never touches it.
  final RuntimeStartIntentStore? _intentStore;
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

    // A deterministic configuration error: reject it once, up front, before
    // cleanup and before the dynamic path can retry it candidate by candidate.
    _requireIntentStoreFor(spec);

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

  /// Re-spawns the runtime on its original, address-frozen [port] after an
  /// unexpected exit.
  ///
  /// Unlike [start] this runs no stale cleanup and never moves to another port:
  /// the runtime's HTTP/SSE stack is pinned to [port], so a restart must reclaim
  /// that exact address. The previous child has already exited; this waits for
  /// the address to free (bounded by [portReleaseTimeout]) — if it never frees
  /// it throws [PluginStartException], which the caller treats as terminal.
  /// Otherwise it spawns a fresh child and writes the new ownership record and
  /// confirms health on exactly the cold-start path (including intent side-file
  /// handling and rollback).
  Future<ManagedRuntimeHandle<R>> restartOnPort({
    required ManagedRuntimeSpec<R> spec,
    required int port,
    required Duration portReleaseTimeout,
    required Duration portReleasePollInterval,
    StartAbortSignal? startAborted,
  }) async {
    // Reject a misconfigured intent timing up front, before waiting on the port,
    // so a direct caller fails fast and clearly instead of crashing on a null
    // intent store deep inside the spawn path.
    _requireIntentStoreFor(spec);
    final abort = startAborted ?? StartAbortSignal.never;
    _throwIfAborted(abort);
    await _waitForPortRelease(
      spec: spec,
      port: port,
      timeout: portReleaseTimeout,
      pollInterval: portReleasePollInterval,
      abort: abort,
    );
    return _startAndConfirmHealthy(spec: spec, port: port, abort: abort);
  }

  /// A managed runtime that opts into intent side-file timing must be given an
  /// intent store; selecting the timing without one is a deterministic
  /// configuration error, surfaced before any side effects.
  void _requireIntentStoreFor(ManagedRuntimeSpec<R> spec) {
    if (spec.recordTiming == RuntimeRecordTiming.intentSideFile && _intentStore == null) {
      throw ArgumentError("[$_runtimeId] intent side-file record timing requires an intent store");
    }
  }

  Future<void> _waitForPortRelease({
    required ManagedRuntimeSpec<R> spec,
    required int port,
    required Duration timeout,
    required Duration pollInterval,
    required StartAbortSignal abort,
  }) async {
    final deadline = _clock.now().add(timeout);
    // A hard backstop independent of the clock: a misconfigured (e.g.
    // non-advancing) clock must fail loud, never hang the supervisor.
    final maxPolls = _portReleaseMaxPolls(timeout: timeout, pollInterval: pollInterval);
    var polls = 0;
    while (true) {
      _throwIfAborted(abort);
      if (await spec.probePortBindable(port: port)) {
        return;
      }
      polls += 1;
      if (polls >= maxPolls || !_clock.now().isBefore(deadline)) {
        throw PluginStartException(
          "[$_runtimeId] port $port did not free for restart within ${timeout.inMilliseconds}ms",
          cause: null,
        );
      }
      await _clock.delay(duration: pollInterval);
    }
  }

  int _portReleaseMaxPolls({required Duration timeout, required Duration pollInterval}) {
    if (pollInterval <= Duration.zero) {
      return 1;
    }
    return (timeout.inMicroseconds / pollInterval.inMicroseconds).ceil() + 2;
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

      // Honor cancellation on every iteration boundary, including the ones
      // that only skip an invalid candidate, so an abort during an all-invalid
      // tail settles as an abort rather than a generic exhaustion failure.
      _throwIfAborted(abort);

      if (port == policy.reservedPort || port < policy.minPort || port > policy.maxPort) {
        continue;
      }

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
    final usesIntent = spec.recordTiming == RuntimeRecordTiming.intentSideFile;
    if (usesIntent) {
      // Record the spawn intent before the child exists, so a crash between
      // spawn and the ownership write still names the bridge run and the port.
      await _intentStore!.write(
        RuntimeStartIntent(
          ownerSessionId: _bridge.ownerSessionId,
          port: port,
          bridgePid: _bridge.identity.pid,
          bridgeStartMarker: _bridge.identity.startMarker,
          recordedAt: _clock.now(),
        ),
      );
    }

    // Spawn errors propagate before any ownership state is acquired: the
    // explicit-port caller surfaces them raw, the dynamic caller retries.
    final SpawnedProcess spawned;
    try {
      spawned = await spec.spawn(port: port);
    } on Object {
      if (usesIntent) {
        await _clearIntentQuietly();
      }
      rethrow;
    }

    // The documented post-spawn abort checkpoint: settle here, before any
    // ownership state is created, so an abort that fired during the spawn does
    // not first write a starting record only to roll it straight back. The
    // freshly spawned child is still untracked, so stop it directly.
    if (abort.isAborted) {
      await _stopUntrackedSpawnQuietly(process: spawned, port: port, reason: "after a post-spawn abort");
      if (usesIntent) {
        await _clearIntentQuietly();
      }
      throw const PluginStartAbortedException();
    }

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
      await _stopUntrackedSpawnQuietly(process: spawned, port: port, reason: "after a record build error");
      if (usesIntent) {
        await _clearIntentQuietly();
      }
      rethrow;
    }
    trackOwnedRuntime(ownerSessionId: _ownerSessionIdOf(record: record), process: spawned);

    try {
      await _ownershipRepository.upsert(record: record);
      if (usesIntent) {
        // The starting record is now in the frozen ownership file; an orphan is
        // trackable from there, so the intent has done its job.
        await _clearIntentQuietly();
      }
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
      if (usesIntent) {
        await _clearIntentQuietly();
      }
      rethrow;
    }
  }

  /// Best-effort removal of the intent side file. An intent-clear failure must
  /// never mask the start error that prompted it, so this only logs.
  Future<void> _clearIntentQuietly() async {
    final store = _intentStore;
    if (store == null) {
      return;
    }
    try {
      await store.clear();
    } on Object catch (error, stackTrace) {
      Log.w("[$_runtimeId] Failed to clear the runtime start-intent side file", error, stackTrace);
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

  /// Stops an untracked, unrecorded child without letting the stop failure mask
  /// the start outcome that triggered it (an abort, a record-build error). Only
  /// logs on failure.
  Future<void> _stopUntrackedSpawnQuietly({
    required SpawnedProcess process,
    required int port,
    required String reason,
  }) async {
    try {
      await _stopUntrackedSpawn(process: process);
    } on Object catch (cleanupError, cleanupStackTrace) {
      Log.w("[$_runtimeId] Failed to stop an orphaned child $reason on port $port", cleanupError, cleanupStackTrace);
    }
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
