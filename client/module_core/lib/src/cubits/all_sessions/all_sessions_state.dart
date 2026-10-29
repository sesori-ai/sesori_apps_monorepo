import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../errors/remote_failure_reason.dart";
import "../../services/models/session_list_quick_filter.dart";
import "../../services/models/session_window_state.dart";

part "all_sessions_state.freezed.dart";

/// One session of the all-projects list, with its project and what its row
/// shows of its live state.
@Freezed()
sealed class AllSessionsRow with _$AllSessionsRow {
  const factory({
    required Session session,
    required ProjectSummary project,
    required bool isRunning,
    required bool isUnseen,
    required bool isAwaitingInput,
    required bool isRetrying,
    required int backgroundTaskCount,
  }) = _AllSessionsRow;
}

/// How many sessions each chip would show under the current query.
@Freezed()
sealed class const SessionListChipCounts._() with _$SessionListChipCounts {
  const factory({
    required int all,
    required int running,
    required int unread,
  }) = _SessionListChipCounts;

  int of({required SessionListQuickFilter filter}) => switch (filter) {
    SessionListQuickFilter.all => all,
    SessionListQuickFilter.running => running,
    SessionListQuickFilter.unread => unread,
  };
}

/// An unchanged resolve is an equal state, so the cubit emits nothing. The
/// lists stay the ones the cubit made, so a list identical to the previous
/// state's is unchanged.
@Freezed(makeCollectionsUnmodifiable: false)
sealed class AllSessionsState with _$AllSessionsState {
  const factory({
    /// The project the list is filtered to, or null for every project.
    required String? projectId,
    required String query,
    required SessionListQuickFilter quickFilter,

    /// The loaded sessions, newest first, by last update (archived: by archive
    /// time) and never by status, narrowed by the filter, the query, the chip
    /// and the hidden sessions. Date headings are the presentation's, over
    /// this order.
    required List<AllSessionsRow> rows,

    /// The bridge's counts under the filter and the query. A hidden session
    /// stays counted until the change that hides it reaches the bridge.
    required SessionListChipCounts counts,

    /// The page after [rows], or null when every matching session is listed.
    required SessionWindowLoadMore? loadMore,

    /// Whether [rows] are the previous search, filter or chip narrowed to
    /// this one until the bridge answers: rows it lacks may still come.
    required bool awaitingAnswer,

    /// Why the sessions could not be loaded, with none to show.
    required RemoteFailureReason? failure,

    /// Whether the project list or the sessions are still loading for the
    /// first time, or a retry after a failure has not answered yet.
    required bool isLoading,

    /// The bridge's "No project" project, or null on a bridge without one.
    required String? scratchProjectId,

    /// The new-session default: the filter, otherwise [scratchProjectId],
    /// otherwise the project of the newest session, otherwise null. The newest
    /// session is read only while nothing narrows the list, and kept through a
    /// search or a chip; until it is known the default stays null, so a
    /// consumer that holds the first default it sees never holds a guess.
    required String? defaultProjectId,
  }) = _AllSessionsState;
}
