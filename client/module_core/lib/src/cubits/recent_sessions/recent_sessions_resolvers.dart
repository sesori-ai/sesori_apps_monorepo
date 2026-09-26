import "package:sesori_shared/sesori_shared.dart";

import "../../services/models/recent_sessions_entry.dart";
import "../../services/session_activity_calculator.dart";

/// Surface-neutral presentation derivation, following SessionListResolvers.
/// Ordering/filtering remain owned by SessionListService; this chooses its head.
extension RecentSessionsResolvers on RecentSessionsLoaded {
  /// Every running session, the first [idleLimit] others, and the selected one
  /// wherever it sits, all in list order.
  List<Session> rows({required String? selectedSessionId, required int idleLimit}) {
    final rows = <Session>[];
    var idle = 0;
    for (final session in visibleSessions) {
      final running = isRunning(session: session);
      if (running || idle < idleLimit || session.id == selectedSessionId) rows.add(session);
      if (!running) idle++;
    }
    return rows;
  }

  bool isUnseen({required Session session}) => listStateBySessionId[session.id]?.unseen ?? session.unseen;

  bool isRunning({required Session session}) {
    final activity = activityBySessionId[session.id];
    return activity != null && const SessionActivityCalculator().isRunning(activity: activity);
  }

  bool isAwaitingInput({required Session session}) => activityBySessionId[session.id]?.awaitingInput ?? false;
}
