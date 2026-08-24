import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

class ManagedRuntimeStatusReporter({
  required final PluginStatusController _status,
  required final ServerClock _clock,
  required final Duration _degradedDebounce,
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
    unawaited(_applyDegradedAfterDebounce(generation: generation, since: since));
  }

  void markDegradedNow() {
    if (_disposed) return;
    _generation++;
    final since = _degradedSince ??= _clock.now();
    _status.trySet(
      PluginDegraded(since: since, recoverable: true, requiresUserAction: false, userActionHint: null),
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _degradedSince = null;
  }

  Future<void> _applyDegradedAfterDebounce({required int generation, required DateTime since}) async {
    try {
      await _clock.delay(duration: _degradedDebounce);
    } on Object {
      return;
    }
    if (_disposed || generation != _generation) return;
    _status.trySet(
      PluginDegraded(since: since, recoverable: true, requiresUserAction: false, userActionHint: null),
    );
  }
}
