import "package:freezed_annotation/freezed_annotation.dart";

part "gh_pull_request.freezed.dart";

@freezed
sealed class GhPullRequest with _$GhPullRequest {
  const factory GhPullRequest({
    required int number,
    required String url,
    required String title,
    required String state,
    required String headRefName,
    required String? mergeable,
    required String? reviewDecision,
    required String? statusCheckRollup,
  }) = _GhPullRequest;
}
