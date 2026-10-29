import "package:sesori_shared/sesori_shared.dart";

import "../../errors/remote_failure_reason.dart";
import "session_list_quick_filter.dart";

/// What a session window lists: one project or every project, a search, and
/// a chip.
typedef SessionWindowKey = ({String? projectId, String? query, SessionListQuickFilter filter});

sealed class const SessionWindowState();

/// Nothing to show yet: the first answer for this computer has not arrived.
final class const SessionWindowLoading() extends SessionWindowState;

final class const SessionWindowLoaded({
  /// Root sessions under the window's key, newest first (archived: most
  /// recently archived first), ties broken by id descending, as the bridge
  /// orders them.
  required final List<Session> sessions,

  /// What each chip holds under the key's project and query.
  required final SessionPageCounts counts,

  /// Where the next page starts, or null when every matching session is
  /// loaded.
  required final String? nextCursor,
  required final SessionWindowLoadMore loadMore,
}) extends SessionWindowState;

/// The first answer failed, with no rows to keep showing.
final class const SessionWindowFailed({required final RemoteFailureReason reason}) extends SessionWindowState;

/// The state of the request for the page after the loaded rows.
enum SessionWindowLoadMore() {
  idle,
  loading,
  failed,
}

sealed class const SessionWindowSearchResult();

/// The newest sessions matching the query, at most the requested number.
final class const SessionWindowSearchMatches({required final List<Session> sessions}) extends SessionWindowSearchResult;

final class const SessionWindowSearchFailure({required final RemoteFailureReason reason})
    extends SessionWindowSearchResult;
