/// How an archive or delete that went through treated the session's worktree.
enum SessionCleanupOutcome() {
  /// Done as requested: the worktree was removed, or none was asked to be.
  completed,

  /// Another live session still uses the worktree, so it was left in place.
  sharedWorktreeKept,
}
