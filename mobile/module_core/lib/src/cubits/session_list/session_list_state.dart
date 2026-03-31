import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/sse/session_activity_info.dart";

part "session_list_state.freezed.dart";

@Freezed()
sealed class SessionListState with _$SessionListState {
  const factory SessionListState.loading() = SessionListLoading;

  // ignore: no_slop_linter/prefer_required_named_parameters, optional base branch is absent for some projects
  const factory SessionListState.loaded({
    required List<Session> sessions,
    @Default(false) bool showArchived,

    /// Map of active session ID -> activity info.
    ///
    /// A session is "active" when either its main agent or any of its direct
    /// child tasks are running.
    @Default({}) Map<String, SessionActivityInfo> activeSessionIds,
    @Default(false) bool isRefreshing,

    /// The base branch of the project (e.g. "main", "develop"), if available.
    String? baseBranch,
  }) = SessionListLoaded;

  /// The requested project ID no longer resolves to the expected project on
  /// the server.
  const factory SessionListState.staleProject({
    /// The project ID the server actually resolved.
    required String resolvedProjectId,
  }) = SessionListStaleProject;

  const factory SessionListState.failed({required ApiError error}) = SessionListFailed;
}
