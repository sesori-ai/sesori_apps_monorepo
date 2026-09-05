import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class const PendingTrackedEvent({
  required final String pluginId,
  required final int generation,
  required final BridgeSseEvent event,
  required final int projectionUpdatedAt,
}) {
  String get backendSessionId;
}

final class const PendingSessionEvent({
  required super.pluginId,
  required super.generation,
  required super.event,
  required final Session session,
  required super.projectionUpdatedAt,
}) extends PendingTrackedEvent {
  @override
  String get backendSessionId => session.id;
}

final class const PendingTranslationEvent({
  required super.pluginId,
  required super.generation,
  required super.event,
  @override required final String backendSessionId,
  required super.projectionUpdatedAt,
}) extends PendingTrackedEvent;

class SessionEventTracker({required final int maxPendingEntriesPerPlugin}) {
  static const defaultMaxPendingEntries = 1024;

  final Map<String, List<PendingTrackedEvent>> _insertionOrderByPlugin = {};
  final Map<({String pluginId, String backendSessionId}), PendingSessionEvent> _sessions = {};
  final Map<({String pluginId, String backendSessionId}), List<PendingTranslationEvent>> _translations = {};

  this {
    if (maxPendingEntriesPerPlugin < 1) {
      throw ArgumentError.value(maxPendingEntriesPerPlugin, "maxPendingEntriesPerPlugin", "must be positive");
    }
  }

  int get length => _insertionOrderByPlugin.values.fold(0, (total, entries) => total + entries.length);

  PendingTrackedEvent? addRoot({required PendingSessionEvent event}) {
    if (event.session.parentID != null) {
      throw ArgumentError("pending root event must not carry a parent session id");
    }
    final key = (pluginId: event.pluginId, backendSessionId: event.session.id);
    _replaceSession(key: key);
    _sessions[key] = event;
    return _append(event: event);
  }

  PendingTrackedEvent? addChild({required PendingSessionEvent event}) {
    final parentId = event.session.parentID;
    if (parentId == null) {
      throw ArgumentError("pending child event must carry a parent session id");
    }
    final bindingKey = (pluginId: event.pluginId, backendSessionId: event.session.id);
    final previous = _sessions[bindingKey];
    if (previous != null && previous.generation != event.generation) {
      _removeSession(event: previous, dropTranslations: true);
    }
    if (_translations[bindingKey]?.isNotEmpty ?? false) {
      return addTranslation(
        event: PendingTranslationEvent(
          pluginId: event.pluginId,
          generation: event.generation,
          event: event.event,
          backendSessionId: event.session.id,
          projectionUpdatedAt: event.projectionUpdatedAt,
        ),
      );
    }
    _replaceSession(key: bindingKey);
    _sessions[bindingKey] = event;
    return _append(event: event);
  }

  PendingSessionEvent? takeRoot({required String pluginId, required String backendSessionId}) {
    final key = (pluginId: pluginId, backendSessionId: backendSessionId);
    final event = _sessions[key];
    if (event == null || event.session.parentID != null) return null;
    _sessions.remove(key);
    _insertionOrder(event.pluginId).remove(event);
    return event;
  }

  bool isBindingPending({
    required String pluginId,
    required int generation,
    required String backendSessionId,
  }) {
    return _sessions[(pluginId: pluginId, backendSessionId: backendSessionId)]?.generation == generation;
  }

  int? pendingBindingGeneration({required String pluginId, required String backendSessionId}) {
    return _sessions[(pluginId: pluginId, backendSessionId: backendSessionId)]?.generation;
  }

  PendingTrackedEvent? addTranslation({required PendingTranslationEvent event}) {
    final key = (pluginId: event.pluginId, backendSessionId: event.backendSessionId);
    if (!_sessions.containsKey(key)) {
      throw ArgumentError("pending translation must wait for a tracked session binding");
    }
    (_translations[key] ??= []).add(event);
    return _append(event: event);
  }

  PendingTrackedEvent? takeNextReady({
    required Set<({String pluginId, String backendSessionId})> readyBindings,
  }) {
    final pluginIds = {for (final binding in readyBindings) binding.pluginId};
    for (final event in [for (final pluginId in pluginIds) ..._insertionOrder(pluginId)]) {
      final bindingKey = switch (event) {
        PendingSessionEvent(:final pluginId, session: Session(:final parentID?)) => (
          pluginId: pluginId,
          backendSessionId: parentID,
        ),
        PendingSessionEvent() => null,
        PendingTranslationEvent(:final pluginId, :final backendSessionId) => (
          pluginId: pluginId,
          backendSessionId: backendSessionId,
        ),
      };
      if (bindingKey == null || !readyBindings.contains(bindingKey)) continue;
      switch (event) {
        case final PendingSessionEvent sessionEvent:
          _removeSession(event: sessionEvent, dropTranslations: false);
        case final PendingTranslationEvent translationEvent:
          _removeTranslation(event: translationEvent);
      }
      return event;
    }
    return null;
  }

  void _replaceSession({required ({String pluginId, String backendSessionId}) key}) {
    final previous = _sessions[key];
    if (previous == null) return;
    _removeSession(event: previous, dropTranslations: false);
  }

  PendingTrackedEvent? _append({required PendingTrackedEvent event}) {
    final insertionOrder = _insertionOrder(event.pluginId)..add(event);
    if (insertionOrder.length <= maxPendingEntriesPerPlugin) return null;

    final evicted = insertionOrder.removeAt(0);
    switch (evicted) {
      case final PendingSessionEvent sessionEvent:
        _removeSession(event: sessionEvent, dropTranslations: true);
      case final PendingTranslationEvent translationEvent:
        _removeTranslation(event: translationEvent);
    }
    return evicted;
  }

  void _removeSession({required PendingSessionEvent event, required bool dropTranslations}) {
    _insertionOrder(event.pluginId).remove(event);
    final bindingKey = (pluginId: event.pluginId, backendSessionId: event.session.id);
    if (identical(_sessions[bindingKey], event)) _sessions.remove(bindingKey);
    if (dropTranslations) {
      final translations = _translations.remove(bindingKey);
      translations?.forEach((translation) => _insertionOrder(translation.pluginId).remove(translation));
    }
  }

  void _removeTranslation({required PendingTranslationEvent event}) {
    _insertionOrder(event.pluginId).remove(event);
    final key = (pluginId: event.pluginId, backendSessionId: event.backendSessionId);
    final translations = _translations[key];
    translations?.remove(event);
    if (translations?.isEmpty ?? false) _translations.remove(key);
  }

  List<PendingTrackedEvent> _insertionOrder(String pluginId) {
    return _insertionOrderByPlugin.putIfAbsent(pluginId, () => <PendingTrackedEvent>[]);
  }
}
