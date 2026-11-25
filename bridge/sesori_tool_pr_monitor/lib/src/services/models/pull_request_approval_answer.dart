/// What became of an auto-merge change the user answered on an Allow card.
enum PullRequestApprovalAnswer() {
  allowed,
  declined,

  /// Allowed, but what the card described no longer holds, so nothing was
  /// applied: the auto-merge settings changed while it was open, or the
  /// watch it was for ended.
  outdated,
}
