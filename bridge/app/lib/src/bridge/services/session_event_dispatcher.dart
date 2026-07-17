import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "session_event_service.dart";

class SessionEventDispatcher {
  final SessionEventService _sessionEventService;
  final StreamController<BridgeSseEvent> _eventsController = StreamController<BridgeSseEvent>.broadcast();
  Future<void> _tail = Future<void>.value();
  bool _disposed = false;

  SessionEventDispatcher({required SessionEventService sessionEventService})
    : _sessionEventService = sessionEventService;

  Stream<BridgeSseEvent> get events => _eventsController.stream;

  SourcedBridgeEvent capturePluginEvent({required String pluginId, required BridgeSseEvent event}) {
    return _sessionEventService.captureSource(pluginId: pluginId, event: event);
  }

  Future<void> dispatchPluginEvent({required SourcedBridgeEvent source}) {
    return _dispatch(() => _sessionEventService.normalize(source: source));
  }

  Future<void> dispatchBindingsCommitted({required SessionBindingsCommitted commit}) {
    return _dispatch(() => _sessionEventService.handleBindingsCommitted(commit: commit));
  }

  Future<void> dispatchDeletedSession({required Session session}) {
    return _dispatch(() async => [BridgeSseSessionDeleted(info: session.toJson())]);
  }

  void addSourceError(Object error, StackTrace stackTrace) {
    if (!_eventsController.isClosed) _eventsController.addError(error, stackTrace);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _tail;
    await _eventsController.close();
  }

  Future<void> _dispatch(Future<List<BridgeSseEvent>> Function() operation) {
    if (_disposed) return Future.error(StateError("SessionEventDispatcher is disposed"));
    final previous = _tail;
    final release = Completer<void>();
    _tail = release.future;
    return () async {
      await previous;
      try {
        final events = await operation();
        for (final event in events) {
          if (await _sessionEventService.canPublish(event: event)) {
            _eventsController.add(event);
          }
        }
      } on Object catch (error, stackTrace) {
        addSourceError(error, stackTrace);
      } finally {
        release.complete();
      }
    }();
  }
}
