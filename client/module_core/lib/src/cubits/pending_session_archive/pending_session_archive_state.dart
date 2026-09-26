import "package:sesori_shared/sesori_shared.dart" hide SessionCleanupRejection;

import "../../repositories/models/session_cleanup_rejection.dart";

/// The one archive the user can still take back.
sealed class const PendingArchiveWindow();

final class const PendingArchiveIdle() extends PendingArchiveWindow;

final class const PendingArchiveOpen({
  required final Session session,
  required final bool deleteWorktree,
}) extends PendingArchiveWindow;

class const PendingSessionArchiveState({
  required final PendingArchiveWindow window,

  /// Sessions whose archive is in flight or has succeeded during this run. The
  /// bridge publishes no session event on archive, so a committed id stays
  /// here to keep a stale active-looking row hidden.
  required final Set<String> archivingIds,
}) {
  /// Sessions to hide while they still read as unarchived.
  Set<String> get hiddenIds => switch (window) {
    PendingArchiveIdle() => archivingIds,
    PendingArchiveOpen(:final session) => {...archivingIds, session.id},
  };
}

/// How one archive commit ended. One-shot events rather than state, so a late
/// outcome of one session can never overwrite another session's Undo window.
sealed class const PendingSessionArchiveOutcome({required final Session session});

final class const PendingSessionArchiveCommitted({required super.session}) extends PendingSessionArchiveOutcome;

/// Archived, but the worktree was left in place because another live session
/// still uses it. The user is told this happened; they are never asked.
final class const PendingSessionArchiveWorktreeKept({required super.session}) extends PendingSessionArchiveOutcome;

/// The bridge refused to clean up the worktree over something the user owns,
/// such as uncommitted work.
final class const PendingSessionArchiveRefused({
  required super.session,
  required final SessionCleanupRejection rejection,
}) extends PendingSessionArchiveOutcome;

final class const PendingSessionArchiveFailed({required super.session}) extends PendingSessionArchiveOutcome;
