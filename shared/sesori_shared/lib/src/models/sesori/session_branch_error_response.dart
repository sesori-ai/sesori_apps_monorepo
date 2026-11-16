import "package:freezed_annotation/freezed_annotation.dart";

part "session_branch_error_response.freezed.dart";
part "session_branch_error_response.g.dart";

/// Why the bridge refused to edit (rewind) or fork a session.
enum SessionBranchErrorCode() {
  /// The session is running a turn. The client offers to stop it first.
  sessionBusy,

  /// The named message cannot be a branch point: it does not open a turn, the
  /// harness cannot rewind or fork there, or the session's harness does not
  /// support the operation. The response's `message` is the harness's
  /// explanation, written for the user and safe to show, or null when it gave
  /// none.
  branchPointUnavailable,

  /// A fork after the latest finished turn found no finished turn.
  nothingToFork,

  /// The edit named an agent, model or variant the harness no longer offers.
  /// The client refreshes its session options and resends with a supported
  /// selection.
  staleSessionOptions,

  /// An archived origin's worktree was removed and nothing kept where it
  /// stood: neither its branch nor a pinned HEAD remains (a worktree removed
  /// before the bridge pinned HEADs, or whose pin failed). The client offers a new worktree from the
  /// session's base branch and retries the fork with
  /// `ForkSessionRequest.recreateFromBase`.
  worktreeBranchMissing,

  /// The bridge or the harness refused for a reason written for the user.
  /// The response's `message` is that explanation.
  refused,
  unknown,
}

/// Error body of the session edit and fork routes.
@Freezed(fromJson: true, toJson: true)
sealed class SessionBranchErrorResponse with _$SessionBranchErrorResponse {
  const factory({
    @JsonKey(unknownEnumValue: SessionBranchErrorCode.unknown) required SessionBranchErrorCode code,
    required String? message,
  }) = _SessionBranchErrorResponse;

  factory fromJson(Map<String, dynamic> json) => _$SessionBranchErrorResponseFromJson(json);
}
