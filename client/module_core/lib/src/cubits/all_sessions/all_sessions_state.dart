import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../errors/remote_failure_reason.dart";
import "../session_list/session_list_quick_filter.dart";

part "all_sessions_state.freezed.dart";

/// Which sessions an all-projects list shows.
enum AllSessionsMode() {
  active,
  archived,
}

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

/// A project whose sessions could not be loaded, for its retry row.
@Freezed()
sealed class AllSessionsFailure with _$AllSessionsFailure {
  const factory({
    required ProjectSummary project,
    required RemoteFailureReason reason,
  }) = _AllSessionsFailure;
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

    /// Every loaded project's rows in [rows]' order, whatever the filter, the
    /// query and the chip, less the hidden sessions: what a jump-to search
    /// offers.
    required List<AllSessionsRow> everyProjectRows,

    /// Newest first, by last update (archived: by archive time) and never by
    /// status, narrowed by the filter, the query, the chip and the hidden
    /// sessions. Date headings are the presentation's, over this order.
    required List<AllSessionsRow> rows,
    required SessionListChipCounts counts,

    /// The listed projects, under the filter, whose sessions failed to load.
    required List<AllSessionsFailure> failures,

    /// Whether the project list, or a listed project under the filter, is still
    /// loading for the first time, or the archived list's reload on open has not
    /// answered yet.
    required bool isLoading,

    /// The bridge's "No project" project, or null on a bridge without one.
    required String? scratchProjectId,

    /// The new-session default: the filter, otherwise [scratchProjectId],
    /// otherwise the project of the newest session, otherwise null. Without
    /// either it stays null while [isLoading], so a consumer that holds the
    /// first default it sees never holds a project that merely answered first.
    required String? defaultProjectId,
  }) = _AllSessionsState;
}
