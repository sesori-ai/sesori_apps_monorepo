import "dart:async";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show PendingOperations;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../services/interrupted_turn_service.dart";

/// Resolves the turns an earlier bridge run left running, for each plugin as
/// it becomes ready: only a ready plugin can say whether they still run.
class InterruptedTurnListener({
  required final Stream<List<String>> _readyPluginIds,
  required final InterruptedTurnService _service,
}) {
  StreamSubscription<List<String>>? _subscription;
  Set<String> _previousReadyIds = const {};
  final PendingOperations _pendingResolutions = PendingOperations();
  Future<void>? _disposeFuture;
  bool _disposed = false;

  void start() {
    if (_disposed || _subscription != null) return;
    _subscription = _readyPluginIds.listen(
      _handleReadyPluginIds,
      onError: (Object error, StackTrace stackTrace) {
        Log.w("Interrupted turn readiness stream failed", error, stackTrace);
      },
    );
  }

  void _handleReadyPluginIds(List<String> pluginIds) {
    final additions = [
      for (final pluginId in pluginIds)
        if (!_previousReadyIds.contains(pluginId)) pluginId,
    ];
    _previousReadyIds = pluginIds.toSet();
    for (final pluginId in additions) {
      unawaited(
        _pendingResolutions.track(
          operation: _service.resolve(pluginId: pluginId).catchError((Object error, StackTrace stackTrace) {
            Log.w('Could not resolve left running turns of plugin "$pluginId"', error, stackTrace);
          }),
        ),
      );
    }
  }

  /// Memoized so a second caller joins the same drain instead of returning
  /// while a resolution is still writing.
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    await _pendingResolutions.drain();
  }
}
