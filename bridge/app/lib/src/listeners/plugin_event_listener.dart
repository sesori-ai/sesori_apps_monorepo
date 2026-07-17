import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../bridge/services/session_event_dispatcher.dart";

class PluginEventListener {
  final String _pluginId;
  final Stream<BridgeSseEvent> _source;
  final SessionEventDispatcher _dispatcher;
  StreamSubscription<BridgeSseEvent>? _subscription;
  bool _disposed = false;

  PluginEventListener({
    required String pluginId,
    required Stream<BridgeSseEvent> source,
    required SessionEventDispatcher dispatcher,
  }) : _pluginId = pluginId,
       _source = source,
       _dispatcher = dispatcher;

  void start() {
    if (_subscription != null || _disposed) return;
    _subscription = _source.listen(
      (event) {
        final source = _dispatcher.capturePluginEvent(pluginId: _pluginId, event: event);
        unawaited(_dispatcher.dispatchPluginEvent(source: source));
      },
      onError: _dispatcher.addSourceError,
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
  }
}
