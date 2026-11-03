import "dart:async";
import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "managed_process_service.dart";
import "managed_runtime_spec.dart";
import "runtime_restart_policy.dart";

/// Supervises an already-started managed runtime: logs its stderr with a
/// `[runtimeId]` prefix, watches for an unexpected exit, and —
/// when a bounded restart policy is configured — relaunches it on its original,
/// address-frozen port with backoff, publishing lifecycle transitions through
/// the plugin's [PluginStatusController].
///
/// Composes [ManagedProcessService] while owning exit monitoring, bounded
/// restart, and stderr logging.
///
/// Concurrency contract:
/// - Every exit-driven action runs only for the *current* child
///   (`identical(firedProcess, currentHandle.process)`) and only while not
///   disarmed — an exit future for a superseded child is dropped. Bare
///   `Future<int> exitCode` cannot be cancelled, so this identity check, not a
///   subscription cancel, is what makes a stale exit inert.
/// - All status writes go through [PluginStatusController.trySet]; a `Failed`
///   that races a deliberate `Stopping` is silently dropped by the state
///   machine, belt-and-suspenders with [disarm].
/// - [disarm] (called by the owner's shutdown *before* it signals the child)
///   aborts any in-flight restart so the relaunched child is rolled back rather
///   than leaked, and cancels the stderr subscription. It is idempotent.
class ManagedRuntimeMonitor<R>({
  required final ManagedProcessService<R> _service,
  required final ManagedRuntimeSpec<R> _spec,
  required final PluginStatusController _status,
  required final ServerClock _clock,
  required final String _runtimeId,
  required final RuntimeRestartPolicy _restartPolicy,
}) {
  ManagedRuntimeHandle<R>? _currentHandle;
  bool _disarmed = false;
  Future<void>? _activeRestartEpisode;
  // Long-lived stderr logger, cancelled in _cancelStderrSubscription (on
  // restart) and disarm (on stop) rather than where it is created.
  // ignore: cancel_subscriptions
  StreamSubscription<String>? _stderrSubscription;
  StartAbortController? _restartAbort;

  /// The handle for the runtime currently being supervised — updated to the
  /// fresh handle after each successful restart so callers (and the eventual
  /// `stop()`) target the live child.
  ManagedRuntimeHandle<R>? get currentHandle => _currentHandle;

  /// Begins supervising [handle].
  ///
  /// For an attached handle there is no child to watch, so this only records
  /// the handle. For an owned handle it wires stderr logging and watches the
  /// child's exit. Safe to call once; a no-op once disarmed.
  void arm(ManagedRuntimeHandle<R> handle) {
    if (_disarmed) {
      return;
    }
    _currentHandle = handle;
    if (handle case OwnedRuntimeHandle(:final process)) {
      _watchProcess(process);
    }
  }

  /// Stops supervising: aborts any in-flight restart (so its freshly spawned
  /// child is rolled back, not leaked), **waits for that restart episode to
  /// settle**, and cancels the stderr subscription.
  ///
  /// The settle-wait is what makes the owner's shutdown safe: when this
  /// returns, an aborted restart has already rolled its fresh child back, and
  /// a restart that had committed past its last abort checkpoint has already
  /// been adopted into [currentHandle] — so the owner stops the *live* child
  /// and never reads a stale handle while a respawn is still in flight. The
  /// wait is bounded: the episode observes the abort at its next checkpoint,
  /// and the backoff sleep itself races the abort signal.
  ///
  /// The owner calls this *before* signaling the child during shutdown, so the
  /// child's deliberate exit is never mistaken for a crash. Idempotent.
  Future<void> disarm() async {
    if (_disarmed) {
      return;
    }
    _disarmed = true;
    _restartAbort?.abort();
    final episode = _activeRestartEpisode;
    if (episode != null) {
      // The episode handles its own errors; a throw here must never leave the
      // stderr subscription dangling or mask the owner's shutdown.
      try {
        await episode;
      } on Object catch (error, stackTrace) {
        Log.w("[$_runtimeId] restart episode failed while disarming", error, stackTrace);
      }
    }
    await _cancelStderrSubscription();
  }

  void _watchProcess(SpawnedProcess process) {
    // The spawn seam already drains both pipes (DrainingSpawnedProcess), so
    // this only logs stderr. allowMalformed: a crashing runtime can emit
    // non-UTF-8 bytes on stderr; a strict decoder would throw and tear down the
    // logger, so substitute instead.
    final stderrLines = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter());
    _stderrSubscription = stderrLines.listen(
      (line) => Log.d("[$_runtimeId] $line"),
      onError: (Object _) {},
      cancelOnError: false,
    );

    // exitCode is a bare Future with no cancel; _onUnexpectedExit re-checks the
    // current-child identity and the disarm flag, so a stale completion is inert.
    unawaited(
      process.exitCode.then((code) => _onUnexpectedExit(process: process, exitCode: code)).catchError((Object _) {}),
    );
  }

  Future<void> _onUnexpectedExit({required SpawnedProcess process, required int exitCode}) async {
    final current = _currentHandle;
    if (_disarmed || current is! OwnedRuntimeHandle<R> || !identical(process, current.process)) {
      return;
    }
    final policy = _restartPolicy;
    // Without restarts, a clean exit after startup is the runtime stopping on
    // its own, not a crash; a bounded policy still respawns its child, and an
    // exit before startup completes stays a failure.
    if (policy is DisabledRestartPolicy && exitCode == 0 && _status.current is! PluginStarting) {
      Log.i("[$_runtimeId] runtime exited on its own with code 0");
      _status.trySet(const PluginStopping());
      _status.trySet(const PluginStopped());
      return;
    }
    Log.e("[$_runtimeId] runtime exited unexpectedly with code $exitCode");

    switch (policy) {
      case DisabledRestartPolicy():
        _status.trySet(
          PluginFailed(reason: "[$_runtimeId] runtime exited unexpectedly with code $exitCode", cause: null),
        );
      case BoundedRestartPolicy():
        // Tracked so disarm() can wait the episode out: returning from disarm
        // while a respawn is mid-flight would let the owner's shutdown stop a
        // stale record while this episode commits a child nobody ever stops.
        final episode = _runRestartEpisode(policy: policy, port: current.port, exitCode: exitCode);
        _activeRestartEpisode = episode;
        try {
          await episode;
        } finally {
          if (identical(_activeRestartEpisode, episode)) {
            _activeRestartEpisode = null;
          }
        }
    }
  }

  Future<void> _runRestartEpisode({
    required BoundedRestartPolicy policy,
    required int port,
    required int exitCode,
  }) async {
    final reason = "runtime exited with code $exitCode";
    final abort = StartAbortController();
    _restartAbort = abort;

    Object? lastError;
    try {
      for (var attempt = 1; attempt <= policy.maxAttempts; attempt += 1) {
        if (_disarmed) {
          return;
        }
        if (!_status.trySet(PluginRestarting(attempt: attempt, reason: reason))) {
          // The status machine rejected the transition — the plugin is stopping,
          // stopped, or already failed — so stand down instead of spawning a
          // child into a terminal/shutdown state.
          return;
        }
        // The backoff sleep races the abort signal: disarm() waits this episode
        // out, so an un-raced sleep would stall shutdown for up to maxBackoff.
        // The losing delay future is sunk — a throwing clock seam must not
        // surface as an unhandled async error after an abort won the race.
        final backoff = _clock.delay(duration: policy.backoffFor(attempt));
        unawaited(backoff.catchError((Object _) {}));
        await Future.any(<Future<void>>[backoff, abort.signal.whenAborted]);
        if (_disarmed) {
          return;
        }

        try {
          final handle = await _service.restartOnPort(
            spec: _spec,
            port: port,
            portReleaseTimeout: policy.portReleaseTimeout,
            portReleasePollInterval: policy.portReleasePollInterval,
            startAborted: abort.signal,
          );
          // Adopt the freshly started child *before* any stand-down check: if a
          // disarm raced the final ownership write, restartOnPort still committed
          // (and is tracking) this child, so it must become the current handle
          // or the owner's shutdown would stop the wrong (dead) child and leak
          // it. _adoptRestartedHandle leaves the new child unwatched when disarmed.
          _adoptRestartedHandle(handle);
          if (_disarmed) {
            return;
          }
          // A concurrent recovery (e.g. the SSE layer flipping back to Ready)
          // means this episode is stale, so announce nothing further.
          if (_status.current is! PluginRestarting) {
            return;
          }
          _status.trySet(const PluginReady());
          return;
        } on PluginStartAbortedException {
          // Disarmed mid-restart: restartOnPort already rolled back the child
          // and record. Nothing to fail; the shutdown owns the outcome.
          return;
        } on Object catch (error, stackTrace) {
          // Log every failed attempt: PluginFailed only carries the last error,
          // so without this an early failure in a multi-attempt episode is silent.
          Log.w("[$_runtimeId] restart attempt $attempt failed", error, stackTrace);
          lastError = error;
        }
      }

      _status.trySet(
        PluginFailed(
          reason: "[$_runtimeId] runtime could not be restarted after ${policy.maxAttempts} attempt(s)",
          cause: lastError,
        ),
      );
    } finally {
      // Only clear the controller this episode owns: if a later episode has
      // already taken over _restartAbort, nulling it here would leave that
      // episode's in-flight restart unabortable by disarm().
      if (identical(_restartAbort, abort)) {
        _restartAbort = null;
      }
    }
  }

  void _adoptRestartedHandle(OwnedRuntimeHandle<R> handle) {
    // Cancel the exited child's stderr logger before wiring the new child's.
    unawaited(_cancelStderrSubscription());
    _currentHandle = handle;
    // When disarmed (a shutdown raced this restart), the child is now tracked
    // and reachable via _currentHandle for the owner's stop, but it must not be
    // re-watched: a fresh exit watch could only fire after disarm and would be
    // dropped anyway, and leaving a stderr subscription would be a needless leak.
    if (!_disarmed) {
      _watchProcess(handle.process);
    }
  }

  Future<void> _cancelStderrSubscription() async {
    final stderrSubscription = _stderrSubscription;
    _stderrSubscription = null;
    // This runs unawaited from _adoptRestartedHandle, so a throwing cancel would
    // surface as an unhandled async error; swallow (logged) to keep teardown safe.
    try {
      await stderrSubscription?.cancel();
    } on Object catch (error, stackTrace) {
      Log.w("[$_runtimeId] Failed to cancel the runtime stderr drain", error, stackTrace);
    }
  }
}
