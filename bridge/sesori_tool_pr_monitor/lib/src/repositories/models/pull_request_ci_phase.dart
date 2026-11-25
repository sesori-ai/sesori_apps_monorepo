/// Where a PR head's checks stand.
enum PullRequestCiPhase() {
  /// The head commit has no checks.
  none,

  /// At least one check is still pending.
  running,

  /// Every check finished.
  concluded,
}
