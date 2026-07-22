import "package:sesori_shared/sesori_shared.dart";

import "session_list_state.dart";

/// Pure-data resolvers for [SessionListLoaded].
///
/// Keeps data-derivation logic in module_core rather than in presentation
/// widgets, satisfying the layered architecture.
extension SessionListResolvers on SessionListLoaded {
  /// The effective unseen state for [session]: the cubit's live
  /// [SessionListLoaded.unseenBySessionId] tracking when present, else what
  /// the session payload itself said.
  bool isSessionUnseen({required Session session}) => unseenBySessionId[session.id] ?? session.unseen;
}
