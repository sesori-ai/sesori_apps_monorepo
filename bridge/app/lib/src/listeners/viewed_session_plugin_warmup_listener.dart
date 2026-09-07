import "dart:async";

import "package:rxdart/rxdart.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../services/plugin_warmup_service.dart";
import "../services/plugin_warmup_settings_service.dart";
import "../services/session_view_tracker.dart";

/// Warms the plugin behind each session while session-open warm-up is enabled.
class ViewedSessionPluginWarmupListener({
  required final SessionViewTracker _tracker,
  required final PluginWarmupService _warmupService,
  required final PluginWarmupSettingsService _settingsService,
}) {
  final CompositeSubscription _subscriptions = CompositeSubscription();
  final PendingOperations _activeWarmups = PendingOperations();
  Future<void>? _disposeFuture;
  bool _disposed = false;
  bool _started = false;

  void start() {
    if (_started || _disposed) return;
    _started = true;

    _tracker.viewStarts
        .listen(
          (sessionId) => _admit(sessionId: sessionId),
          onError: (Object error, StackTrace stackTrace) {
            if (_disposed) return;
            Log.w("Session view tracking failed during plugin warm-up", error, stackTrace);
          },
        )
        .addTo(_subscriptions);
  }

  void _admit({required String sessionId}) {
    if (_disposed || !_settingsService.isEnabled) return;
    unawaited(
      _activeWarmups.track(
        operation: _warm(sessionId: sessionId),
      ),
    );
  }

  Future<void> _warm({required String sessionId}) async {
    try {
      await _warmupService.warmForSession(sessionId: sessionId);
    } on Object catch (error, stackTrace) {
      if (_disposed) return;
      Log.w('Session-open plugin warm-up failed for session "$sessionId"', error, stackTrace);
    }
  }

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    await _subscriptions.cancel();
    await _activeWarmups.drain();
  }
}
