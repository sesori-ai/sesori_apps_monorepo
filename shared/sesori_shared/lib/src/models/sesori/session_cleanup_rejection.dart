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

  @FreezedUnionValue("branch_mismatch")
  const factory branchMismatch({
    required String expected,
    required String actual,
  }) = CleanupIssueBranchMismatch;

  @FreezedUnionValue("shared_worktree")
  const factory sharedWorktree() = CleanupIssueSharedWorktree;

  factory fromJson(Map<String, dynamic> json) => _$CleanupIssueFromJson(json);
}
