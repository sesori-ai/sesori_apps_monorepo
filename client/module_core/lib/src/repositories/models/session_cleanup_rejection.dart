import "package:sesori_shared/sesori_shared.dart" show CleanupIssue, CleanupIssueSharedWorktree;

import "../../api/session_api.dart" show SessionCleanupApiRejectedException;

class const SessionCleanupRejection({required final List<CleanupIssue> issues}) {
  /// True when a live session sharing the worktree is the only thing in the
  /// way. Nothing of the user's is at risk, so that case is retried without
  /// worktree cleanup instead of being put to them as a question.
  ///
  /// False for an empty list: a refusal that names no issue is not something to
  /// silently retry.
  bool get isOnlySharedWorktree => issues.isNotEmpty && issues.every((issue) => issue is CleanupIssueSharedWorktree);
}

class const SessionCleanupRejectedException({
  required final SessionCleanupRejection rejection,
  required final SessionCleanupApiRejectedException innerError,
}) implements Exception;
