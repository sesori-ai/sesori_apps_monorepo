import "package:sesori_shared/sesori_shared.dart";

import "../../services/models/recent_sessions_entry.dart";
import "../../services/session_activity_calculator.dart";

/// Surface-neutral presentation derivation, following SessionListResolvers.
extension RecentSessionsResolvers on RecentSessionsLoaded {
  bool isUnseen({required Session session}) => listStateBySessionId[session.id]?.unseen ?? session.unseen;

  bool isRunning({required Session session}) {
    final activity = activityBySessionId[session.id];
    return activity != null && const SessionActivityCalculator().isRunning(activity: activity);
  }

  bool isAwaitingInput({required Session session}) => activityBySessionId[session.id]?.awaitingInput ?? false;
}
