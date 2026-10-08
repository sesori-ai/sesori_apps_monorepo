import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// What a lasting loss of the runtime's server becomes once the debounce
/// passes without a reconnect.
enum ManagedRuntimeDisconnectOutcome() {
  /// Stay degraded and keep retrying the same server.
  degrade,

  /// Fail, so the bridge retires this generation and the next request starts
  /// a fresh one that can find the server again wherever it now listens.
  fail,
}

class ManagedRuntimeStatusReporter({
  required final PluginStatusController _status,
  required final ServerClock _clock,
  required final Duration _degradedDebounce,
  required final ManagedRuntimeDisconnectOutcome _disconnectOutcome,
}) {
  int _generation = 0;
  DateTime? _degradedSince;
  bool _disposed = false;

  PluginStatusController get status => _status;

  void markConnected() {
    if (_disposed) return;
    _generation++;
    _degradedSince = null;
    _status.trySet(const PluginReady());
  }

  void markDisconnected() {
    if (_disposed || _degradedSince != null) return;
    final since = _degradedSince = _clock.now();
    final generation = ++_generation;
    unawaited(_applyOutcomeAfterDebounce(generation: generation, since: since));
  }

  void markDegradedNow() {
    if (_disposed) return;
    final generation = ++_generation;
    final since = _degradedSince ??= _clock.now();
    _status.trySet(_degraded(since: since));
    if (_disconnectOutcome == ManagedRuntimeDisconnectOutcome.fail) {
      unawaited(_applyOutcomeAfterDebounce(generation: generation, since: since));
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _degradedSince = null;
  }

  Future<void> _applyOutcomeAfterDebounce({required int generation, required DateTime since}) async {
    try {
      await _clock.delay(duration: _degradedDebounce);
    } on Object {
      return;
    }
    if (_disposed || generation != _generation) return;
    _status.trySet(switch (_disconnectOutcome) {
      ManagedRuntimeDisconnectOutcome.degrade => _degraded(since: since),
      ManagedRuntimeDisconnectOutcome.fail => const PluginFailed(reason: "the server stopped answering", cause: null),
    });
  }

  PluginDegraded _degraded({required DateTime since}) =>
      PluginDegraded(since: since, recoverable: true, requiresUserAction: false, userActionHint: null);
}
