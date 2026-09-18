import "package:collection/collection.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../services/session_activity_calculator.dart";
import "recent_sessions_state.dart";

/// Surface-neutral presentation derivation, following SessionListResolvers.
/// Ordering/filtering remain owned by SessionListService; this chooses its head.
extension RecentSessionsResolvers on RecentSessionsLoaded {
  List<Session> rows({required String? selectedSessionId, required Set<String> excludingSessionIds}) {
    final ordinarySessions = visibleSessions.where((session) => !excludingSessionIds.contains(session.id));
    final recent = ordinarySessions.take(3).toList();
    final selected = ordinarySessions.firstWhereOrNull((session) => session.id == selectedSessionId);
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
