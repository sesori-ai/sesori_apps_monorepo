import "dart:async";

import "../bridge/runtime/plugin_runtime.dart";
import "../bridge/services/session_event_dispatcher.dart";

class PluginEventListener({
  required final Stream<SourcedPluginRuntimeEvent> _source,
  required final SessionEventDispatcher _dispatcher,
}) {
  StreamSubscription<SourcedPluginRuntimeEvent>? _subscription;
  bool _disposed = false;

  void start() {
    if (_subscription != null || _disposed) return;
    _subscription = _source.listen(
      (event) {
        final source = _dispatcher.capturePluginEvent(
          pluginId: event.pluginId,
          generation: event.generation,
          event: event.event,
        );
        unawaited(
          _dispatcher.dispatchPluginEvent(
            source: source,
            allowDuringStop: event.allowDuringStop,
            terminalHandoffConsumed: event.terminalHandoffConsumed,
          ),
        );
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
