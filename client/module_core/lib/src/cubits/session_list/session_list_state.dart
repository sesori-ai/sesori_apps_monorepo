import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../errors/remote_failure_reason.dart";
import "../../services/models/session_activity_info.dart";

part "session_list_state.freezed.dart";

@Freezed()
sealed class SessionListState with _$SessionListState {
  const factory SessionListState.loading() = SessionListLoading;

  const factory SessionListState.loaded({
    required List<Session> sessions,
    @Default(false) bool showArchived,

    /// Map of active session ID -> activity info.
    ///
    /// A session is "active" when either its main agent or any of its direct
    /// child tasks are running.
    @Default({}) Map<String, SessionActivityInfo> activeSessionIds,
    @Default(false) bool isRefreshing,

    /// Map of session ID -> whether it has unseen changes (bold title). Merges
    /// the REST-seeded `Session.unseen` with live `SesoriSessionUnseenChanged`
    /// updates, the latter taking precedence.
    @Default({}) Map<String, bool> unseenBySessionId,

    /// The base branch of the project (e.g. "main", "develop"), if available.
    required String? baseBranch,
  }) = SessionListLoaded;

  /// The requested project ID no longer resolves to the expected project on
  /// the server.
  const factory SessionListState.staleProject({
    /// The project ID the server actually resolved.
    required String resolvedProjectId,
  }) = SessionListStaleProject;

  const factory SessionListState.failed({required RemoteFailureReason reason}) = SessionListFailed;
}
