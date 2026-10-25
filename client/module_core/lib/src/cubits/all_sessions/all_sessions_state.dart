import "package:sesori_shared/sesori_shared.dart";

import "../../errors/remote_failure_reason.dart";
import "../session_list/session_list_quick_filter.dart";

/// Which sessions an all-projects list shows.
enum AllSessionsMode() {
  active,
  archived,
}

/// One session of the all-projects list, with its project and what its row
/// shows of its live state.
final class const AllSessionsRow({
  required final Session session,
  required final ProjectSummary project,
  required final bool isRunning,
  required final bool isUnseen,
  required final bool isAwaitingInput,
  required final bool isRetrying,
  required final int backgroundTaskCount,
});

/// A project whose sessions could not be loaded, for its retry row.
final class const AllSessionsFailure({
  required final ProjectSummary project,
  required final RemoteFailureReason reason,
});

/// How many sessions each chip would show under the current query.
final class const SessionListChipCounts({
  required final int all,
  required final int running,
  required final int unread,
}) {
  int of({required SessionListQuickFilter filter}) => switch (filter) {
    SessionListQuickFilter.all => all,
    SessionListQuickFilter.running => running,
    SessionListQuickFilter.unread => unread,
  };
}

final class const AllSessionsState({
  /// The project the list is filtered to, or null for every project.
  required final String? projectId,
  required final String query,
  required final SessionListQuickFilter quickFilter,

  /// Every loaded project's rows in [rows]' order, whatever the filter, the
  /// query and the chip, less the hidden sessions: what a jump-to search
  /// offers.
  required final List<AllSessionsRow> everyProjectRows,

  /// Newest first, by last update (archived: by archive time) and never by
  /// status, narrowed by the filter, the query, the chip and the hidden
  /// sessions. Date headings are the presentation's, over this order.
  required final List<AllSessionsRow> rows,
  required final SessionListChipCounts counts,

  /// The listed projects, under the filter, whose sessions failed to load.
  required final List<AllSessionsFailure> failures,

  /// Whether the project list, or a listed project under the filter, is still
  /// loading for the first time.
  required final bool isLoading,

  /// The new-session default: the filter, otherwise the project of the newest
  /// session, otherwise null.
  required final String? defaultProjectId,
});
