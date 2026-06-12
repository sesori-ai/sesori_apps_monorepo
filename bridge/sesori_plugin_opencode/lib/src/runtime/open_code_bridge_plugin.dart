import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart" show ManagedProcessService, ManagedRuntimeMonitor;

import "open_code_ownership_record.dart";

/// Drives the plugin's [PluginStatusController] from the SSE transport's
/// connect/disconnect callbacks, with a debounced degradation so a brief drop
/// (a reconnect blip, a supervisor restart) does not flap the reported status.
///
/// Mirrors the `SteadyPluginLifecycle` debounce semantics: a disconnect surfaces
/// as [PluginDegraded] only after [degradedDebounce] elapses without an
/// intervening reconnect; `since` keeps the first observation; a reconnect
/// applies [PluginReady] immediately and cancels any pending degradation. All
/// writes go through [PluginStatusController.trySet], so a degrade that races a
/// monitor-emitted [PluginFailed] or a deliberate shutdown is dropped by the
/// state machine.
class OpenCodeRuntimeStatusReporter {
  OpenCodeRuntimeStatusReporter({
    required PluginStatusController status,
    required ServerClock clock,
    Duration degradedDebounce = const Duration(seconds: 5),
  }) : _status = status,
       _clock = clock,
       _degradedDebounce = degradedDebounce;

  final PluginStatusController _status;
  final ServerClock _clock;
  final Duration _degradedDebounce;

  int _generation = 0;
  DateTime? _degradedSince;
  bool _disposed = false;

  /// The shared status controller this reporter publishes to.
  PluginStatusController get status => _status;

  /// Transport connected (or cold-start completed): cancel any pending
  /// degradation and report [PluginReady] immediately.
  void markConnected() {
    if (_disposed) {
      return;
    }
    _generation++;
    _degradedSince = null;
    _status.trySet(const PluginReady());
  }

  /// Transport dropped: schedule a [PluginDegraded] after [degradedDebounce],
  /// unless a later connect/disconnect supersedes it. The first observation
  /// time is retained as `since`.
  void markDisconnected() {
    if (_disposed) {
      return;
    }
    final generation = ++_generation;
    final since = _degradedSince ??= _clock.now();
    unawaited(_applyDegradedAfterDebounce(generation, since));
  }

  /// Reports [PluginDegraded] immediately (e.g. when cold-start fails on
  /// startup), without waiting out the debounce window.
  void markDegradedNow() {
    if (_disposed) {
      return;
    }
    _generation++;
    final since = _degradedSince ??= _clock.now();
    _status.trySet(
      PluginDegraded(since: since, recoverable: true, requiresUserAction: false, userActionHint: null),
    );
  }

  Future<void> _applyDegradedAfterDebounce(int generation, DateTime since) async {
    try {
      await _clock.delay(duration: _degradedDebounce);
    } on Object {
      return;
    }
    if (_disposed || generation != _generation) {
      return;
    }
    _status.trySet(
      PluginDegraded(since: since, recoverable: true, requiresUserAction: false, userActionHint: null),
    );
  }

  /// Stops any pending degradation. Called by the plugin's `shutdown()`.
  void dispose() {
    _disposed = true;
    _generation++;
  }
}

/// Live-plugin wrapper for the managed OpenCode flow.
///
/// Pairs the stable [api] (whose SSE transport auto-reconnects to the
/// address-frozen port across a supervisor restart) with the lifecycle surface:
/// a [PluginStatusController] fed by both the SSE transport (via
/// [OpenCodeRuntimeStatusReporter]) and the exit monitor, plus an ordered,
/// idempotent [shutdown].
class OpenCodeBridgePlugin implements BridgePlugin {
  OpenCodeBridgePlugin({
    required this.api,
    required OpenCodeRuntimeStatusReporter reporter,
    required ManagedRuntimeMonitor<OpenCodeOwnershipRecord> monitor,
    required ManagedProcessService<OpenCodeOwnershipRecord> service,
    required OpenCodeOwnershipRecord? ownedRecord,
    required this.port,
    required this.serverUrl,
  }) : _reporter = reporter,
       _monitor = monitor,
       _service = service,
       _ownedRecord = ownedRecord;

  @override
  final BridgePluginApi api;

  final int port;
  final String serverUrl;

  final OpenCodeRuntimeStatusReporter _reporter;
  final ManagedRuntimeMonitor<OpenCodeOwnershipRecord> _monitor;
  final ManagedProcessService<OpenCodeOwnershipRecord> _service;
  final OpenCodeOwnershipRecord? _ownedRecord;

  Future<void>? _shutdown;

  PluginStatusController get _status => _reporter.status;

  @override
  Stream<PluginStatus> get status => _status.stream;

  @override
  PluginStatus get currentStatus => _status.current;

  @override
  PluginDiagnostics describe() {
    return PluginDiagnostics(
      pluginId: "opencode",
      endpoint: serverUrl,
      details: {
        "port": "$port",
        "mode": _ownedRecord == null ? "attached" : "managed",
      },
    );
  }

  /// Stops the plugin in order: disarm the monitor (so the child's deliberate
  /// exit is never mistaken for a crash), tear down the api, then stop the owned
  /// `opencode serve` process (when this bridge owns one). Idempotent — repeated
  /// calls return the same future — and safe before/after
  /// [BridgePluginApi.dispose], which the orchestrator still calls directly
  /// until PR 12.
  ///
  /// [budget] is accepted but not subdivided: the stop path keeps its own
  /// pacing (graceful signal, wait, force). The shutdown coordinator's backstop,
  /// sized from the same budget, bounds the total.
  @override
  Future<void> shutdown({required Duration? budget}) => _shutdown ??= _shutdownNow();

  Future<void> _shutdownNow() async {
    _reporter.dispose();
    if (!_status.isClosed && _status.current is! PluginStopped) {
      _status.trySet(const PluginStopping());
    }
    try {
      // Disarm before signaling the child so its deliberate exit is not
      // mistaken for a crash (no spurious restart / PluginFailed).
      await _monitor.disarm();

      Object? disposeError;
      StackTrace? disposeStackTrace;
      try {
        await api.dispose();
      } catch (error, stackTrace) {
        // The owned server must still be stopped when api teardown fails.
        disposeError = error;
        disposeStackTrace = stackTrace;
        Log.e("[opencode] plugin api dispose failed: $error");
      }

      // The monitor's current handle reflects any restart-adopted child;
      // fall back to the record captured at start.
      final record = _monitor.currentHandle?.record ?? _ownedRecord;
      if (record != null) {
        await _service.stopOwnedRuntime(record: record);
      }

      if (disposeError != null) {
        Error.throwWithStackTrace(disposeError, disposeStackTrace!);
      }
    } finally {
      if (!_status.isClosed) {
        _status.trySet(const PluginStopped());
      }
    }
  }
}
