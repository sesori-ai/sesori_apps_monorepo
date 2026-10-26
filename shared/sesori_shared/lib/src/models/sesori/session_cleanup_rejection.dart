import "package:freezed_annotation/freezed_annotation.dart";

part "session_cleanup_rejection.freezed.dart";

part "session_cleanup_rejection.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class SessionCleanupRejection with _$SessionCleanupRejection {
  const factory({
    required List<CleanupIssue> issues,
  }) = _SessionCleanupRejection;

  factory fromJson(Map<String, dynamic> json) => _$SessionCleanupRejectionFromJson(json);
}

@Freezed(unionKey: "type", fromJson: true, toJson: true)
sealed class CleanupIssue with _$CleanupIssue {
  @FreezedUnionValue("unstaged_changes")
  const factory unstagedChanges() = CleanupIssueUnstagedChanges;

  // COMPATIBILITY 2026-09-26 (v1.9.1): v1.7.1 and older bridges send branch_mismatch cleanup issues. Remove when v1.7.1 bridges are unsupported.
  @FreezedUnionValue("branch_mismatch")
  const factory branchMismatch({
    required String expected,
    required String actual,
  }) = CleanupIssueBranchMismatch;

  @FreezedUnionValue("shared_worktree")
  const factory sharedWorktree() = CleanupIssueSharedWorktree;

  /// The worktree's HEAD has commits that no branch, tag or remote reaches, so
  /// removing the worktree would lose them.
  @FreezedUnionValue("commits_on_no_branch")
  const factory commitsOnNoBranch() = CleanupIssueCommitsOnNoBranch;

  factory fromJson(Map<String, dynamic> json) => _$CleanupIssueFromJson(json);
}
