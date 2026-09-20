import "package:collection/collection.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../services/models/recent_sessions_entry.dart";
import "../../services/session_activity_calculator.dart";

/// Surface-neutral presentation derivation, following SessionListResolvers.
/// Ordering/filtering remain owned by SessionListService; this chooses its head.
extension RecentSessionsResolvers on RecentSessionsLoaded {
  List<Session> rows({required String? selectedSessionId}) {
    final recent = visibleSessions.take(3).toList();
    final selected = visibleSessions.firstWhereOrNull((session) => session.id == selectedSessionId);
    return [
      ...recent,
      if (selected != null && !recent.any((session) => session.id == selected.id)) selected,
    ];
  }

  bool isUnseen({required Session session}) => listStateBySessionId[session.id]?.unseen ?? session.unseen;

  bool isRunning({required Session session}) {
    final activity = activityBySessionId[session.id];
    return activity != null && const SessionActivityCalculator().isRunning(activity: activity);
  }

  bool isAwaitingInput({required Session session}) => activityBySessionId[session.id]?.awaitingInput ?? false;
}
