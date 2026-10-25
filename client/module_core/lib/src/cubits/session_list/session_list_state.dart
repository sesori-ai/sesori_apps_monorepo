import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../services/models/session_activity_info.dart";

part "session_list_state.freezed.dart";

@Freezed()
sealed class SessionListState with _$SessionListState {
  const factory({
    required List<Session> sessions,

    /// Map of active session ID -> activity info.
    ///
    /// A session is "active" when either its main agent or any of its direct
    /// child tasks are running.
    required Map<String, SessionActivityInfo> activeSessionIds,

    /// Map of session ID -> whether it has unseen changes (bold title). Merges
    /// the REST-seeded `Session.unseen` with live `SesoriSessionUnseenChanged`
    /// updates, the latter taking precedence.
    required Map<String, bool> unseenBySessionId,
  }) = _SessionListState;
}
