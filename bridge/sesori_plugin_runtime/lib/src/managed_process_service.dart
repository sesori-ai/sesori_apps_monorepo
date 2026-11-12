import "package:meta/meta.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "host_json_runtime_ownership_repository.dart";
import "managed_runtime_spec.dart";
import "runtime_record_mapper.dart";

class ManagedProcessService<R>({
  required final HostJsonRuntimeOwnershipRepository<R> _ownershipRepository,
  required final RuntimeRecordMapper<R> _mapper,
  required final HostProcessService _processes,
  required final BridgeHostInfo _bridge,
  required final ServerClock _clock,
  required final bool _isWindows,
  required final String _runtimeId,
  required final Duration _gracefulShutdownWait,
}) {
  static const Duration _staleExitPollInterval = Duration(milliseconds: 100);

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
  Future<OwnedRuntimeHandle<R>> start({
    required ManagedRuntimeSpec<R> spec,
    required List<ProcessIdentity> terminatedBridgeIdentities,
    required StartAbortSignal startAborted,
  }) async {
    final abort = startAborted;

    await cleanupStaleOwnedRuntimes(terminatedBridgeIdentities: terminatedBridgeIdentities);
    _throwIfAborted(abort);

    final portPolicy = spec.portPolicy;
    switch (portPolicy) {
      case ExplicitPortPolicy():
        return await _startOnExplicitPort(spec: spec, policy: portPolicy, abort: abort);
      case DynamicPortPolicy():
        return await _startOnDynamicPort(spec: spec, policy: portPolicy, abort: abort);
    }
  }

  /// Attaches to a runtime already listening on [port] (the `--no-auto-start`
  /// path): a single health probe, no ownership, no process to kill. Returns
  /// an attached handle on success; throws [PluginStartException] when the
  /// existing server is unreachable.
  Future<AttachedRuntimeHandle<R>> attach({
    required ManagedRuntimeSpec<R> spec,
    required int port,
    required StartAbortSignal startAborted,
  }) async {
    final abort = startAborted;
    _throwIfAborted(abort);

    final probe = await _probeTolerant(spec: spec, port: port);
    // Honor an abort that fired while the probe was in flight: even a healthy
    // result must not produce a live handle once the bridge has aborted.
    _throwIfAborted(abort);
    if (!probe.healthy) {
      throw PluginStartException(
        "[$_runtimeId] existing runtime health check failed on port $port",
        cause: probe.error,
        userFacingReason: null,
      );
    }

    return AttachedRuntimeHandle<R>(port: port);
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
  /// confirms health on exactly the cold-start path, including rollback.
  Future<OwnedRuntimeHandle<R>> restartOnPort({
    required ManagedRuntimeSpec<R> spec,
    required int port,
    required Duration portReleaseTimeout,
    required Duration portReleasePollInterval,
    required StartAbortSignal startAborted,
  }) async {
    final abort = startAborted;
    _throwIfAborted(abort);
    await _waitForPortRelease(
      spec: spec,
      port: port,
      timeout: portReleaseTimeout,
      pollInterval: portReleasePollInterval,
      abort: abort,
    );
    return await _startAndConfirmHealthy(spec: spec, port: port, abort: abort);
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
    final maxPolls = _boundedMaxPolls(timeout: timeout, pollInterval: pollInterval);
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
          userFacingReason: null,
        );
      }
      await _clock.delay(duration: pollInterval);
    }
  }

  int _boundedMaxPolls({required Duration timeout, required Duration pollInterval}) {
    if (pollInterval <= Duration.zero) {
      return 1;
    }
    return (timeout.inMicroseconds / pollInterval.inMicroseconds).ceil() + 2;
  }

  Future<OwnedRuntimeHandle<R>> _startOnExplicitPort({
    required ManagedRuntimeSpec<R> spec,
    required ExplicitPortPolicy policy,
    required StartAbortSignal abort,
  }) async {
    final bindable = await spec.probePortBindable(port: policy.port);
    if (!bindable) {
      throw PluginStartException(
        "[$_runtimeId] explicit port ${policy.port} is already in use",
        cause: null,
        userFacingReason: null,
      );
    }
    _throwIfAborted(abort);
    return await _startAndConfirmHealthy(spec: spec, port: policy.port, abort: abort);
  }

  Future<OwnedRuntimeHandle<R>> _startOnDynamicPort({
    required ManagedRuntimeSpec<R> spec,
    required DynamicPortPolicy policy,
    required StartAbortSignal abort,
  }) async {
    Object? lastError;
    var attempts = 0;

    for (final port in policy.candidates) {
      attempts += 1;
      // Honor cancellation on every iteration boundary, including the ones
      // that only skip an unbindable candidate.
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
        // A failure after a successful spawn (health check): the port was
        // bindable but the runtime did not come up on it, so try the next
        // candidate. A spawn that could not launch at all is not caught here —
        // it is a fatal configuration or environment fault, and retrying it
        // candidate by candidate would only repeat the same failure.
        lastError = error;
      }
    }

    throw PluginStartException(
      "[$_runtimeId] unable to start runtime on an available dynamic port after $attempts attempt(s)",
      cause: lastError,
      userFacingReason: null,
    );
  }

  Future<OwnedRuntimeHandle<R>> _startAndConfirmHealthy({
    required ManagedRuntimeSpec<R> spec,
    required int port,
    required StartAbortSignal abort,
  }) async {
    // Spawn errors propagate before any ownership state is acquired: the
    // explicit-port caller surfaces them raw, the dynamic caller retries.
    final spawned = await spec.spawn(port: port);

    // The documented post-spawn abort checkpoint: settle here, before any
    // ownership state is created, so an abort that fired during the spawn does
    // not first write a starting record only to roll it straight back. The
    // freshly spawned child is still untracked, so stop it directly.
    if (abort.isAborted) {
      await _stopUntrackedSpawnQuietly(process: spawned, port: port, reason: "after a post-spawn abort");
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
      rethrow;
    }
    trackOwnedRuntime(
      ownerSessionId: _ownerSessionIdOf(record: record),
      process: spawned,
    );

    try {
      await _ownershipRepository.upsert(record: record);
      _throwIfAborted(abort);

      await _confirmHealthy(spec: spec, port: port, spawned: spawned, abort: abort);

      _throwIfAborted(abort);

      final readyRecord = _mapper.markReady(record: record);
      await _ownershipRepository.upsert(record: readyRecord);

      return OwnedRuntimeHandle<R>(port: port, record: readyRecord, process: spawned);
    } on Object {
      // Never let a cleanup failure mask the error that triggered it.
      try {
        await _stopRecord(record: record);
      } on Object catch (cleanupError, cleanupStackTrace) {
        Log.w("[$_runtimeId] Failed to clean up after a failed start on port $port", cleanupError, cleanupStackTrace);
      }
      rethrow;
    }
  }

  Future<void> _confirmHealthy({
    required ManagedRuntimeSpec<R> spec,
    required int port,
    required SpawnedProcess spawned,
    required StartAbortSignal abort,
  }) async {
    final policy = spec.healthPolicy;
    final deadline = _clock.now().add(policy.deadline);
    // The same clock-independent backstop as the port-release wait: a
    // non-advancing clock can never reach the deadline, so only a poll
    // cap keeps an unhealthy runtime from spinning this loop forever
    // under the startup mutex.
    final maxPolls = _boundedMaxPolls(timeout: policy.deadline, pollInterval: policy.pollInterval);
    var polls = 0;
    while (true) {
      await _clock.delay(duration: policy.pollInterval);
      final probe = await _probeOnce(spec: spec, port: port, spawned: spawned, abort: abort);
      if (probe.healthy) {
        return;
      }
      polls += 1;
      if (polls >= maxPolls || !_clock.now().isBefore(deadline)) {
        throw PluginStartException(
          "[$_runtimeId] health check failed on port $port within ${policy.deadline.inMilliseconds}ms",
          cause: probe.error,
          userFacingReason: null,
        );
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

    if (await _spawnedProcessExited(process: spawned)) {
      // The child we launched is gone; a healthy probe now would be answered
      // by an unrelated process holding the port. Fail authoritatively.
      throw PluginStartException(
        "[$_runtimeId] runtime exited before becoming healthy on port $port",
        cause: null,
        userFacingReason: null,
      );
    }

    return await _probeTolerant(spec: spec, port: port);
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
    if (await _requestGracefulStop(pid: process.pid)) {
      await _awaitGracefulExit(process: process);
    }
    if (!await _spawnedProcessExited(process: process)) {
      await _processes.signalForce(pid: process.pid);
    }
  }

  /// Requests a graceful stop without letting its failure skip the force step
  /// that follows. Windows refuses a non-forced `taskkill` for a windowless
  /// console runtime, so the caller's own checks must still decide on force.
  ///
  /// Returns whether the signal was sent. When it was not — the request failed,
  /// or the process was already gone — there is no graceful exit to wait for,
  /// so the caller skips the grace wait and goes straight to its force checks.
  Future<bool> _requestGracefulStop({required int pid}) async {
    try {
      final result = await _processes.signalGraceful(pid: pid);
      return result.wasRequested;
    } on Object catch (error, stackTrace) {
      Log.w(
        "[$_runtimeId] Graceful stop of pid $pid failed; force stopping it if it is still running",
        error,
        stackTrace,
      );
      return false;
    }
  }

  /// Waits out the grace period after a graceful signal, ending as soon as
  /// [process] exits. A runtime with no handle in this bridge gets the full
  /// period, since only the handle reports its exit.
  Future<void> _awaitGracefulExit({required SpawnedProcess? process}) async {
    final graceElapsed = _clock.delay(duration: _gracefulShutdownWait);
    if (process == null) {
      await graceElapsed;
      return;
    }
    await Future.any<void>([process.exitCode, graceElapsed]);
  }

  void _throwIfAborted(StartAbortSignal abort) {
    if (abort.isAborted) {
      throw const PluginStartAbortedException();
    }
  }

  /// Public only so stop-path tests can seed a tracked child; production
  /// tracks a child only from [start] and [restartOnPort].
  @visibleForTesting
  void trackOwnedRuntime({required String ownerSessionId, required SpawnedProcess process}) {
    _currentOwnedProcessesBySessionId[ownerSessionId] = _CurrentOwnedRuntimeProcess(
      process: process,
      identity: process.identity,
    );
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

    // Each failed request is logged and reported as not sent. A request that
    // hangs past the timeout may still land, so it keeps the grace wait.
    final gracefulRequests = Future.wait(
      recordsToTerminate.map((record) => _requestGracefulStop(pid: _runtimePidOf(record: record))),
    ).then((sent) => sent.contains(true));
    final anyGracefulSignalSent = await gracefulRequests.timeout(
      _gracefulShutdownWait,
      onTimeout: () {
        Log.w("[$_runtimeId] Graceful stop of some runtime instance(s) timed out");
        return true;
      },
    );

    if (anyGracefulSignalSent) {
      await _awaitStaleExit(records: recordsToTerminate);
    }

    final survivors = <R>[];
    for (final record in recordsToTerminate) {
      if (await _isStaleRecordRunning(record: record)) {
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

  /// Waits out the grace period after stale runtimes were signalled, polling
  /// the process table so the wait ends as soon as none of them is running.
  Future<void> _awaitStaleExit({required List<R> records}) async {
    final deadline = _clock.now().add(_gracefulShutdownWait);
    var running = records;
    while (running.isNotEmpty && _clock.now().isBefore(deadline)) {
      await _clock.delay(duration: _staleExitPollInterval);
      running = [
        for (final record in running)
          if (await _isStaleRecordRunning(record: record)) record,
      ];
    }
  }

  Future<bool> _isStaleRecordRunning({required R record}) async {
    final currentOwned = _currentOwnedProcessFor(record: record);
    final currentOwnedStillRunning = currentOwned != null && await _isCurrentOwnedProcessRunning(process: currentOwned);
    final remainingIdentity = await _processes.inspect(pid: _runtimePidOf(record: record));
    final matchesRemaining =
        remainingIdentity != null && _matchesRuntimeRecord(identity: remainingIdentity, record: record);
    return currentOwnedStillRunning || matchesRemaining;
  }

  Future<void> stopOwnedRuntime({required R record}) async {
    await _ownershipRepository.upsert(record: _mapper.markStopping(record: record));
    await _stopRecord(record: record);
  }

  Future<void> _stopRecord({required R record}) async {
    final currentOwnedProcess = _currentOwnedProcessFor(record: record);
    final initialIdentity = await _processes.inspect(pid: _runtimePidOf(record: record));
    final matchesInitialIdentity =
        initialIdentity != null && _matchesRuntimeRecord(identity: initialIdentity, record: record);
    if (!matchesInitialIdentity && currentOwnedProcess == null) {
      await _ownershipRepository.deleteByOwnerSessionId(ownerSessionId: _ownerSessionIdOf(record: record));
      return;
    }

    if (!matchesInitialIdentity && currentOwnedProcess != null) {
      final currentOwnedStillRunningBeforeGraceful = await _isCurrentOwnedProcessRunning(process: currentOwnedProcess);
      if (!currentOwnedStillRunningBeforeGraceful) {
        _currentOwnedProcessesBySessionId.remove(_ownerSessionIdOf(record: record));
        await _ownershipRepository.deleteByOwnerSessionId(ownerSessionId: _ownerSessionIdOf(record: record));
        return;
      }
    }

    if (await _requestGracefulStop(pid: _runtimePidOf(record: record))) {
      await _awaitGracefulExit(process: currentOwnedProcess?.process);
    }

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
      await _ownershipRepository.deleteByOwnerSessionId(ownerSessionId: _ownerSessionIdOf(record: record));
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
          actual: process.identity.executablePath,
          expected: _runtimeExecutablePathOf(record: record),
        ) &&
        _endsWithRuntimeArgs(identity: process.identity, record: record);
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
      // The pid and start marker pin the exact process instance. The
      // executable is not compared because an interpreter shim or a launcher
      // that execs its native binary changes it after spawn.
      return identity.startMarker == _runtimeStartMarkerOf(record: record) &&
          _endsWithRuntimeArgs(identity: identity, record: record);
    }
    return _samePath(
      actual: identity.executablePath,
      expected: _runtimeExecutablePathOf(record: record),
    );
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

  bool _samePath({required String? actual, required String? expected}) {
    if (actual == null || expected == null) {
      return false;
    }

    if (!_isWindows) {
      return actual == expected;
    }

    final normalizedActual = _normalizeWindowsPath(actual);
    final normalizedExpected = _normalizeWindowsPath(expected);
    if (normalizedActual == normalizedExpected) {
      return true;
    }

    return _windowsPathBasename(normalizedActual) == _windowsPathBasename(normalizedExpected);
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

  bool _endsWithRuntimeArgs({required ProcessIdentity identity, required R record}) {
    return identity.commandLine.endsWith(" ${_mapper.runtimeArgsOf(record: record).join(" ")}");
  }

  String _ownerSessionIdOf({required R record}) => _mapper.ownerSessionIdOf(record: record);

  int _runtimePidOf({required R record}) => _mapper.runtimePidOf(record: record);

  String? _runtimeStartMarkerOf({required R record}) => _mapper.runtimeStartMarkerOf(record: record);

  String? _runtimeExecutablePathOf({required R record}) => _mapper.runtimeExecutablePathOf(record: record);

  int _bridgePidOf({required R record}) => _mapper.bridgePidOf(record: record);

  String? _bridgeStartMarkerOf({required R record}) => _mapper.bridgeStartMarkerOf(record: record);
}

class const _CurrentOwnedRuntimeProcess({
  required final SpawnedProcess process,
  required final ProcessIdentity identity,
});
