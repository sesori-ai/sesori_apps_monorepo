import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// Drives the plugin's [PluginStatusController] from the codex transport's
/// connect/disconnect callbacks, with a debounced degradation so a brief drop
/// does not flap the reported status.
///
/// Mirrors the `SteadyPluginLifecycle` debounce semantics: a disconnect surfaces
/// as [PluginDegraded] only after [degradedDebounce] elapses without an
/// intervening reconnect; `since` keeps the first observation; a reconnect
/// applies [PluginReady] immediately and cancels any pending degradation. All
/// writes go through [PluginStatusController.trySet], so a degrade that races a
/// monitor-emitted [PluginFailed] or a deliberate shutdown is dropped by the
/// state machine.
class CodexRuntimeStatusReporter {
  CodexRuntimeStatusReporter({
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
