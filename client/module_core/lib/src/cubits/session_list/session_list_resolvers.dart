import "package:sesori_shared/sesori_shared.dart";

import "../../services/session_activity_calculator.dart";
import "session_list_state.dart";

/// Pure-data resolvers for [SessionListLoaded].
///
/// Keeps data-derivation logic in module_core rather than in presentation
/// widgets, satisfying the layered architecture.
extension SessionListResolvers on SessionListLoaded {
  /// Uses the same running classification as service-owned list ordering.
  /// Awaiting-input-only sessions remain in their date group.
  bool isSessionRunning({required Session session}) {
    final activity = activeSessionIds[session.id];
    return activity != null && const SessionActivityCalculator().isRunning(activity: activity);
  }

  /// The effective unseen state for [session]: the cubit's live
  /// [SessionListLoaded.unseenBySessionId] tracking when present, else what
  /// the session payload itself said.
  bool isSessionUnseen({required Session session}) => unseenBySessionId[session.id] ?? session.unseen;
}
