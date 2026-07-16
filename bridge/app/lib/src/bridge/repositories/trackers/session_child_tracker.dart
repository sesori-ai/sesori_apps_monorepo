import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

class PendingChildEvent {
  final String pluginId;
  final BridgeSseEvent event;
  final Session session;

  const PendingChildEvent({
    required this.pluginId,
    required this.event,
    required this.session,
  });
}

class SessionChildTracker {
  static const defaultMaxPendingEntries = 1024;

  final int maxPendingEntries;
  final List<PendingChildEvent> _insertionOrder = [];
  final Map<({String pluginId, String backendParentId}), List<PendingChildEvent>> _byParent = {};

  SessionChildTracker({required this.maxPendingEntries}) {
    if (maxPendingEntries < 1) {
      throw ArgumentError.value(maxPendingEntries, "maxPendingEntries", "must be positive");
    }
  }

  int get length => _insertionOrder.length;

  PendingChildEvent? add({required PendingChildEvent event}) {
    final parentId = event.session.parentID;
    if (parentId == null) {
      throw ArgumentError("pending child event must carry a parent session id");
    }
    final key = (pluginId: event.pluginId, backendParentId: parentId);
    (_byParent[key] ??= []).add(event);
    _insertionOrder.add(event);
    if (_insertionOrder.length <= maxPendingEntries) return null;

    final evicted = _insertionOrder.removeAt(0);
    final evictedParentId = evicted.session.parentID!;
    final evictedKey = (pluginId: evicted.pluginId, backendParentId: evictedParentId);
    final siblings = _byParent[evictedKey]!;
    siblings.remove(evicted);
    if (siblings.isEmpty) _byParent.remove(evictedKey);
    return evicted;
  }

  List<PendingChildEvent> takeChildren({
    required String pluginId,
    required String backendParentId,
  }) {
    final key = (pluginId: pluginId, backendParentId: backendParentId);
    final children = _byParent.remove(key);
    if (children == null) return const [];
    children.forEach(_insertionOrder.remove);
    return children;
  }
}
