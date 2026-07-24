import "dart:async";

import "../bridge/runtime/plugin_runtime.dart";
import "../bridge/services/session_event_dispatcher.dart";

class PluginEventListener {
  final Stream<SourcedPluginRuntimeEvent> _source;
  final SessionEventDispatcher _dispatcher;
  StreamSubscription<SourcedPluginRuntimeEvent>? _subscription;
  bool _disposed = false;

  PluginEventListener({
    required Stream<SourcedPluginRuntimeEvent> source,
    required SessionEventDispatcher dispatcher,
  }) : _source = source,
       _dispatcher = dispatcher;

  void start() {
    if (_subscription != null || _disposed) return;
    _subscription = _source.listen(
      (event) {
        final source = _dispatcher.capturePluginEvent(
          pluginId: event.pluginId,
          generation: event.generation,
          event: event.event,
        );
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
