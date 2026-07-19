import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";
import "session_event_service.dart";

typedef NormalizedSourcedBridgeEvent = ({String pluginId, int? generation, BridgeSseEvent event});

class SessionEventDispatcher {
  final SessionEventService _sessionEventService;
  final StreamController<NormalizedSourcedBridgeEvent> _eventsController =
      StreamController<NormalizedSourcedBridgeEvent>.broadcast();
  final Map<String, Future<void>> _tails = <String, Future<void>>{};
  bool _disposed = false;

  SessionEventDispatcher({required SessionEventService sessionEventService})
    : _sessionEventService = sessionEventService;

  Stream<NormalizedSourcedBridgeEvent> get events => _eventsController.stream;

  SourcedBridgeEvent capturePluginEvent({
    required String pluginId,
    required int generation,
    required BridgeSseEvent event,
  }) {
    return _sessionEventService.captureSource(
      pluginId: pluginId,
      generation: generation,
      event: event,
    );
  }

  Future<void> dispatchPluginEvent({required SourcedBridgeEvent source}) {
    return _dispatch(
      pluginId: source.pluginId,
      generation: source.generation,
      operation: () => _sessionEventService.normalize(source: source),
    );
  }

  Future<void> dispatchBindingsCommitted({required SessionBindingsCommitted commit}) {
    return _dispatch(
      pluginId: commit.pluginId,
      generation: null,
      operation: () => _sessionEventService.handleBindingsCommitted(commit: commit),
    );
  }

  Future<void> dispatchDeletedSession({required Session session}) {
    return _dispatch(
      pluginId: session.pluginId,
      generation: null,
      operation: () async => [BridgeSseSessionDeleted(info: session.toJson())],
    );
  }

  void addSourceError(Object error, StackTrace stackTrace) {
    if (!_eventsController.isClosed) _eventsController.addError(error, stackTrace);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await Future.wait(_tails.values);
    await _eventsController.close();
  }

  Future<void> _dispatch({
    required String pluginId,
    required int? generation,
    required Future<List<BridgeSseEvent>> Function() operation,
  }) {
    if (_disposed) return Future.error(StateError("SessionEventDispatcher is disposed"));
    final previous = _tails[pluginId] ?? Future<void>.value();
    final release = Completer<void>();
    _tails[pluginId] = release.future;
    return () async {
      await previous;
      try {
        final events = await operation();
        if (generation != null &&
            !_sessionEventService.isCurrentGeneration(
              pluginId: pluginId,
              generation: generation,
            )) {
          return;
        }
        for (final event in events) {
          if (await _sessionEventService.canPublish(event: event)) {
            if (generation != null &&
                !_sessionEventService.isCurrentGeneration(
                  pluginId: pluginId,
                  generation: generation,
                )) {
              return;
            }
            _eventsController.add((pluginId: pluginId, generation: generation, event: event));
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
