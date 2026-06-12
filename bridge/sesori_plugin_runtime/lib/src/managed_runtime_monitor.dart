import "dart:async";
import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "managed_process_service.dart";
import "managed_runtime_spec.dart";
import "runtime_restart_policy.dart";

/// Supervises an already-started managed runtime: drains its stdio (logging
/// stderr with a `[runtimeId]` prefix), watches for an unexpected exit, and —
/// when a bounded restart policy is configured — relaunches it on its original,
/// address-frozen port with backoff, publishing lifecycle transitions through
/// the plugin's [PluginStatusController].
///
/// The monitor is a **separate** component that composes [ManagedProcessService]
/// rather than living inside it. The legacy in-place wrapper (and its fidelity
/// gate) drives the service directly and never constructs a monitor, so
/// "exit monitoring / restart / stderr logging" are simply absent there — the
/// way the migration keeps these hardened behaviors off until the flip.
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
///   than leaked, and cancels the stdio subscriptions. It is idempotent.
class ManagedRuntimeMonitor<R> {
  ManagedRuntimeMonitor({
    required ManagedProcessService<R> service,
    required ManagedRuntimeSpec<R> spec,
    required PluginStatusController status,
    required ServerClock clock,
    required String runtimeId,
    required RuntimeRestartPolicy restartPolicy,
  }) : _service = service,
       _spec = spec,
       _status = status,
       _clock = clock,
       _runtimeId = runtimeId,
       _restartPolicy = restartPolicy;

  final ManagedProcessService<R> _service;
  final ManagedRuntimeSpec<R> _spec;
  final PluginStatusController _status;
  final ServerClock _clock;
  final String _runtimeId;
  final RuntimeRestartPolicy _restartPolicy;

  ManagedRuntimeHandle<R>? _currentHandle;
  int? _pinnedPort;
  bool _disarmed = false;
  // Long-lived stdio drains, cancelled in _cancelStdioSubscriptions (on restart)
  // and disarm (on stop) rather than where they are created.
  // ignore: cancel_subscriptions
  StreamSubscription<void>? _stdoutSubscription;
  // ignore: cancel_subscriptions
  StreamSubscription<String>? _stderrSubscription;
  StartAbortController? _restartAbort;

  /// The handle for the runtime currently being supervised — updated to the
  /// fresh handle after each successful restart so callers (and the eventual
  /// `stop()`) target the live child.
  ManagedRuntimeHandle<R>? get currentHandle => _currentHandle;

  /// Begins supervising [handle].
  ///
  /// For an attached (un-owned) handle there is no child to watch, so this only
  /// records the handle. For an owned handle it pins the port, wires the stdout
  /// drain and stderr logging in a single synchronous turn (both are
  /// single-subscription and a full pipe would block the child), and watches
  /// the child's exit. Safe to call once; a no-op once disarmed.
  void arm(ManagedRuntimeHandle<R> handle) {
    if (_disarmed) {
      return;
    }
    _currentHandle = handle;

    final process = handle.process;
    if (process == null) {
      // Attach mode: the bridge connected to a runtime it does not own, so
      // there is no child to drain, watch, or restart.
      return;
    }

    _pinnedPort = handle.port;
    _watchProcess(process);
  }

  /// Stops supervising: aborts any in-flight restart (so its freshly spawned
  /// child is rolled back, not leaked), and cancels the stdio subscriptions.
  ///
  /// The owner calls this *before* signaling the child during shutdown, so the
  /// child's deliberate exit is never mistaken for a crash. Idempotent.
  Future<void> disarm() async {
    if (_disarmed) {
      return;
    }
    _disarmed = true;
    _restartAbort?.abort();
    await _cancelStdioSubscriptions();
  }

  void _watchProcess(SpawnedProcess process) {
    // Wire both stdio drains synchronously: both streams are single
    // subscription and the child blocks on a full pipe, so neither may wait on
    // an await before being consumed. Both subscriptions are long-lived and
    // cancelled in _cancelStdioSubscriptions (on restart) and disarm (on stop).
    _stdoutSubscription = process.stdout.listen((_) {}, onError: (Object _) {}, cancelOnError: false);
    // allowMalformed: a crashing runtime can emit non-UTF-8 bytes on stderr; a
    // strict decoder would throw and tear down the drain, so substitute instead.
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
    unawaited(process.exitCode.then((code) => _onUnexpectedExit(process, code)).catchError((Object _) {}));
  }

  Future<void> _onUnexpectedExit(SpawnedProcess process, int exitCode) async {
    if (_disarmed || !identical(process, _currentHandle?.process)) {
      return;
    }
    Log.e("[$_runtimeId] runtime exited unexpectedly with code $exitCode");

    final policy = _restartPolicy;
    switch (policy) {
      case DisabledRestartPolicy():
        _status.trySet(
          PluginFailed(reason: "[$_runtimeId] runtime exited unexpectedly with code $exitCode", cause: null),
        );
      case BoundedRestartPolicy():
        await _runRestartEpisode(policy: policy, exitCode: exitCode);
    }
  }

  Future<void> _runRestartEpisode({required BoundedRestartPolicy policy, required int exitCode}) async {
    final port = _pinnedPort;
    if (port == null) {
      return;
    }
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
        await _clock.delay(duration: policy.backoffFor(attempt));
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

  void _adoptRestartedHandle(ManagedRuntimeHandle<R> handle) {
    // Cancel the exited child's stdio drains before wiring the new child's.
    unawaited(_cancelStdioSubscriptions());
    _currentHandle = handle;
    final process = handle.process;
    // When disarmed (a shutdown raced this restart), the child is now tracked
    // and reachable via _currentHandle for the owner's stop, but it must not be
    // re-watched: a fresh exit watch could only fire after disarm and would be
    // dropped anyway, and leaving stdio subscriptions would be a needless leak.
    if (process != null && !_disarmed) {
      _watchProcess(process);
    }
  }

  Future<void> _cancelStdioSubscriptions() async {
    final stdoutSubscription = _stdoutSubscription;
    final stderrSubscription = _stderrSubscription;
    _stdoutSubscription = null;
    _stderrSubscription = null;
    // This runs unawaited from _adoptRestartedHandle, so a throwing cancel would
    // surface as an unhandled async error; swallow (logged) to keep teardown safe.
    try {
      await stdoutSubscription?.cancel();
    } on Object catch (error, stackTrace) {
      Log.w("[$_runtimeId] Failed to cancel the runtime stdout drain", error, stackTrace);
    }
    try {
      await stderrSubscription?.cancel();
    } on Object catch (error, stackTrace) {
      Log.w("[$_runtimeId] Failed to cancel the runtime stderr drain", error, stackTrace);
    }
  }
}
