import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

part "session_list_state.freezed.dart";

@Freezed()
sealed class SessionListState with _$SessionListState {
  const factory SessionListState.loading() = SessionListLoading;

  const factory SessionListState.loaded({
    required List<Session> sessions,
    @Default(false) bool showArchived,
    @Default({}) Set<String> activeSessionIds,
  }) = SessionListLoaded;

  /// The requested project ID no longer resolves to the expected project on
  /// the server.
  const factory SessionListState.staleProject({
    /// The project ID the server actually resolved.
    required String resolvedProjectId,
  }) = SessionListStaleProject;

  const factory SessionListState.failed({required ApiError error}) = SessionListFailed;
}
