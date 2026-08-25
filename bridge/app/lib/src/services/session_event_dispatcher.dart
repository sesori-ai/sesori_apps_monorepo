import "dart:async";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show KeyedParallelLock;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../repositories/session_repository.dart";
import "session_event_service.dart";

typedef NormalizedSourcedBridgeEvent = ({
  String pluginId,
  int? generation,
  BridgeSseEvent event,
  bool allowDuringStop,
  Completer<void>? terminalHandoffConsumed,
});
typedef LocalSessionEvent = ({String pluginId, BridgeSseEvent event});
typedef _DispatchEvent = ({
  int? generation,
  BridgeSseEvent event,
  bool allowDuringStop,
  Completer<void>? terminalHandoffConsumed,
});

class SessionEventDispatcher({required final SessionEventService _sessionEventService}) {
  final StreamController<NormalizedSourcedBridgeEvent> _eventsController =
      StreamController<NormalizedSourcedBridgeEvent>.broadcast();
  final KeyedParallelLock<String> _dispatchLock = KeyedParallelLock<String>();
  bool _disposed = false;

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

  Future<void> dispatchPluginEvent({
    required SourcedBridgeEvent source,
    required bool allowDuringStop,
    required Completer<void>? terminalHandoffConsumed,
  }) {
    return _dispatch(
      pluginId: source.pluginId,
      operation: () async {
        final events = await _sessionEventService.normalize(
          source: source,
          allowDuringStop: allowDuringStop,
        );
        return [
          for (var index = 0; index < events.length; index++)
            (
              generation: source.generation,
              event: events[index],
              allowDuringStop: allowDuringStop,
              terminalHandoffConsumed: index == events.length - 1 ? terminalHandoffConsumed : null,
            ),
        ];
      },
    );
  }

  Future<void> dispatchBindingsCommitted({required SessionBindingsCommitted commit}) {
    return _dispatch(
      pluginId: commit.pluginId,
      operation: () async => [
        for (final output in await _sessionEventService.handleBindingsCommitted(commit: commit))
          (
            generation: output.generation,
            event: output.event,
            allowDuringStop: false,
            terminalHandoffConsumed: null,
          ),
      ],
    );
  }

  Future<void> dispatchLocalEvent({required LocalSessionEvent source}) {
    return _dispatch(
      pluginId: source.pluginId,
      operation: () async => [
        (
          generation: null,
          event: source.event,
          allowDuringStop: false,
          terminalHandoffConsumed: null,
        ),
      ],
    );
  }

  void addSourceError(Object error, StackTrace stackTrace) {
    if (!_eventsController.isClosed) _eventsController.addError(error, stackTrace);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _dispatchLock.idle;
    await _eventsController.close();
  }

  Future<void> _dispatch({
    required String pluginId,
    required Future<List<_DispatchEvent>> Function() operation,
  }) {
    if (_disposed) return Future.error(StateError("SessionEventDispatcher is disposed"));
    return _dispatchLock.use(
      key: pluginId,
      operation: () async {
        try {
          final events = await operation();
          for (final output in events) {
            final generation = output.generation;
            final event = output.event;
            if (await _sessionEventService.canPublish(event: event)) {
              if (generation != null &&
                  !_sessionEventService.isCurrentEvent(
                    pluginId: pluginId,
                    generation: generation,
                    allowDuringStop: output.allowDuringStop,
                  )) {
                continue;
              }
              _eventsController.add((
                pluginId: pluginId,
                generation: generation,
                event: event,
                allowDuringStop: output.allowDuringStop,
                terminalHandoffConsumed: output.terminalHandoffConsumed,
              ));
            }
          }
        } on Object catch (error, stackTrace) {
          addSourceError(error, stackTrace);
        }
      },
    );
  }
}
