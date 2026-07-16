import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class PendingTrackedEvent {
  final String pluginId;
  final BridgeSseEvent event;
  final int projectionUpdatedAt;

  const PendingTrackedEvent({
    required this.pluginId,
    required this.event,
    required this.projectionUpdatedAt,
  });

  String get backendSessionId;
}

final class PendingSessionEvent extends PendingTrackedEvent {
  final Session session;

  const PendingSessionEvent({
    required super.pluginId,
    required super.event,
    required this.session,
    required super.projectionUpdatedAt,
  });

  @override
  String get backendSessionId => session.id;
}

final class PendingTranslationEvent extends PendingTrackedEvent {
  @override
  final String backendSessionId;

  const PendingTranslationEvent({
    required super.pluginId,
    required super.event,
    required this.backendSessionId,
    required super.projectionUpdatedAt,
  });
}

class SessionEventTracker {
  static const defaultMaxPendingEntries = 1024;

  final int maxPendingEntries;
  final List<PendingTrackedEvent> _insertionOrder = [];
  final Map<({String pluginId, String backendSessionId}), PendingSessionEvent> _sessions = {};
  final Map<({String pluginId, String backendParentId}), List<PendingSessionEvent>> _children = {};
  final Map<({String pluginId, String backendSessionId}), List<PendingTranslationEvent>> _translations = {};

  SessionEventTracker({required this.maxPendingEntries}) {
    if (maxPendingEntries < 1) {
      throw ArgumentError.value(maxPendingEntries, "maxPendingEntries", "must be positive");
    }
  }

  int get length => _insertionOrder.length;

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
    if (_translations[bindingKey]?.isNotEmpty ?? false) {
      return addTranslation(
        event: PendingTranslationEvent(
          pluginId: event.pluginId,
          event: event.event,
          backendSessionId: event.session.id,
          projectionUpdatedAt: event.projectionUpdatedAt,
        ),
      );
    }
    _replaceSession(key: bindingKey);
    _sessions[bindingKey] = event;
    final key = (pluginId: event.pluginId, backendParentId: parentId);
    (_children[key] ??= []).add(event);
    return _append(event: event);
  }

  PendingSessionEvent? takeRoot({required String pluginId, required String backendSessionId}) {
    final key = (pluginId: pluginId, backendSessionId: backendSessionId);
    final event = _sessions[key];
    if (event == null || event.session.parentID != null) return null;
    _sessions.remove(key);
    _insertionOrder.remove(event);
    return event;
  }

  List<PendingSessionEvent> takeChildren({
    required String pluginId,
    required String backendParentId,
  }) {
    final children = _children.remove((pluginId: pluginId, backendParentId: backendParentId));
    if (children == null) return const [];
    for (final child in children) {
      final key = (pluginId: child.pluginId, backendSessionId: child.session.id);
      if (identical(_sessions[key], child)) _sessions.remove(key);
      _insertionOrder.remove(child);
    }
    return children;
  }

  bool isBindingPending({required String pluginId, required String backendSessionId}) {
    return _sessions.containsKey((pluginId: pluginId, backendSessionId: backendSessionId));
  }

  PendingTrackedEvent? addTranslation({required PendingTranslationEvent event}) {
    final key = (pluginId: event.pluginId, backendSessionId: event.backendSessionId);
    if (!_sessions.containsKey(key)) {
      throw ArgumentError("pending translation must wait for a tracked session binding");
    }
    (_translations[key] ??= []).add(event);
    return _append(event: event);
  }

  List<PendingTranslationEvent> takeTranslations({
    required String pluginId,
    required String backendSessionId,
  }) {
    final translations = _translations.remove((pluginId: pluginId, backendSessionId: backendSessionId));
    if (translations == null) return const [];
    translations.forEach(_insertionOrder.remove);
    return translations;
  }

  List<PendingTrackedEvent> takeReady({
    required String pluginId,
    required String backendSessionId,
  }) {
    final readyBindings = {
      (pluginId: pluginId, backendSessionId: backendSessionId),
    };
    final ready = <PendingTrackedEvent>[];
    while (true) {
      final event = takeNextReady(readyBindings: readyBindings);
      if (event == null) break;
      ready.add(event);
    }
    return ready;
  }

  PendingTrackedEvent? takeNextReady({
    required Set<({String pluginId, String backendSessionId})> readyBindings,
  }) {
    for (final event in _insertionOrder) {
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
    _insertionOrder.add(event);
    if (_insertionOrder.length <= maxPendingEntries) return null;

    final evicted = _insertionOrder.removeAt(0);
    switch (evicted) {
      case final PendingSessionEvent sessionEvent:
        _removeSession(event: sessionEvent, dropTranslations: true);
      case final PendingTranslationEvent translationEvent:
        _removeTranslation(event: translationEvent);
    }
    return evicted;
  }

  void _removeSession({required PendingSessionEvent event, required bool dropTranslations}) {
    _insertionOrder.remove(event);
    final bindingKey = (pluginId: event.pluginId, backendSessionId: event.session.id);
    if (identical(_sessions[bindingKey], event)) _sessions.remove(bindingKey);
    if (event.session.parentID case final parentId?) {
      final parentKey = (pluginId: event.pluginId, backendParentId: parentId);
      final siblings = _children[parentKey];
      siblings?.remove(event);
      if (siblings?.isEmpty ?? false) _children.remove(parentKey);
    }
    if (dropTranslations) {
      final translations = _translations.remove(bindingKey);
      translations?.forEach(_insertionOrder.remove);
    }
  }

  void _removeTranslation({required PendingTranslationEvent event}) {
    _insertionOrder.remove(event);
    final key = (pluginId: event.pluginId, backendSessionId: event.backendSessionId);
    final translations = _translations[key];
    translations?.remove(event);
    if (translations?.isEmpty ?? false) _translations.remove(key);
  }
}
