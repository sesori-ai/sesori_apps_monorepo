import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../bridge/services/session_event_service.dart";

class PluginEventListener {
  final String _pluginId;
  final Stream<BridgeSseEvent> _source;
  final SessionEventService _sessionEventService;
  late final StreamController<BridgeSseEvent> _eventsController;
  StreamSubscription<List<BridgeSseEvent>>? _subscription;
  bool _disposed = false;

  PluginEventListener({
    required String pluginId,
    required Stream<BridgeSseEvent> source,
    required SessionEventService sessionEventService,
  }) : _pluginId = pluginId,
       _source = source,
       _sessionEventService = sessionEventService {
    _eventsController = StreamController<BridgeSseEvent>.broadcast(onListen: _start);
  }

  Stream<BridgeSseEvent> get events => _eventsController.stream;

  void _start() {
    if (_subscription != null || _disposed) return;
    _subscription = _source
        .asyncMap(
          (event) => _sessionEventService.normalize(
            source: (pluginId: _pluginId, event: event),
          ),
        )
        .listen(
          (events) => events.forEach(_eventsController.add),
          onError: _eventsController.addError,
          onDone: _eventsController.close,
        );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
    if (!_eventsController.isClosed) await _eventsController.close();
  }
}
