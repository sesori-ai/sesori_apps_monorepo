import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

class PendingSessionEvent {
  final String pluginId;
  final BridgeSseEvent event;
  final Session session;
  final int projectionUpdatedAt;

  const PendingSessionEvent({
    required this.pluginId,
    required this.event,
    required this.session,
    required this.projectionUpdatedAt,
  });
}

class SessionEventTracker {
  static const defaultMaxPendingEntries = 1024;

  final int maxPendingEntries;
  final List<PendingSessionEvent> _insertionOrder = [];
  final Map<({String pluginId, String backendSessionId}), PendingSessionEvent> _roots = {};
  final Map<({String pluginId, String backendParentId}), List<PendingSessionEvent>> _children = {};

  SessionEventTracker({required this.maxPendingEntries}) {
    if (maxPendingEntries < 1) {
      throw ArgumentError.value(maxPendingEntries, "maxPendingEntries", "must be positive");
    }
  }

  int get length => _insertionOrder.length;

  PendingSessionEvent? addRoot({required PendingSessionEvent event}) {
    if (event.session.parentID != null) {
      throw ArgumentError("pending root event must not carry a parent session id");
    }
    final key = (pluginId: event.pluginId, backendSessionId: event.session.id);
    final previous = _roots[key];
    if (previous != null) _insertionOrder.remove(previous);
    _roots[key] = event;
    return _append(event: event);
  }

  PendingSessionEvent? addChild({required PendingSessionEvent event}) {
    final parentId = event.session.parentID;
    if (parentId == null) {
      throw ArgumentError("pending child event must carry a parent session id");
    }
    final key = (pluginId: event.pluginId, backendParentId: parentId);
    (_children[key] ??= []).add(event);
    return _append(event: event);
  }

  PendingSessionEvent? takeRoot({required String pluginId, required String backendSessionId}) {
    final event = _roots.remove((pluginId: pluginId, backendSessionId: backendSessionId));
    if (event != null) _insertionOrder.remove(event);
    return event;
  }

  List<PendingSessionEvent> takeChildren({
    required String pluginId,
    required String backendParentId,
  }) {
    final children = _children.remove((pluginId: pluginId, backendParentId: backendParentId));
    if (children == null) return const [];
    children.forEach(_insertionOrder.remove);
    return children;
  }

  PendingSessionEvent? _append({required PendingSessionEvent event}) {
    _insertionOrder.add(event);
    if (_insertionOrder.length <= maxPendingEntries) return null;

    final evicted = _insertionOrder.removeAt(0);
    final parentId = evicted.session.parentID;
    if (parentId == null) {
      _roots.remove((pluginId: evicted.pluginId, backendSessionId: evicted.session.id));
    } else {
      final key = (pluginId: evicted.pluginId, backendParentId: parentId);
      final siblings = _children[key]!;
      siblings.remove(evicted);
      if (siblings.isEmpty) _children.remove(key);
    }
    return evicted;
  }
}
