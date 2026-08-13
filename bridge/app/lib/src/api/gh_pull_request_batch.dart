import "package:freezed_annotation/freezed_annotation.dart";

import "../bridge/api/gh_pull_request.dart";

part "gh_pull_request_batch.freezed.dart";
part "gh_pull_request_batch.g.dart";

enum GhPullRequestStateGroup() { open, terminal }

final class const GhPullRequestTarget({
    required final String repositoryOwner,
    required final String repositoryName,
    required final String branchName,
  });

final class const GhPullRequestCursorRequest({
    required final GhPullRequestTarget target,
    required final GhPullRequestStateGroup stateGroup,
    required final String cursor,
  });

sealed class const GhPullRequestQueryException() implements Exception;

final class const GhPullRequestProcessExitException({required final int exitCode}) extends GhPullRequestQueryException {
  @override
  String toString() => "GitHub pull request query failed with exit code $exitCode";
}

final class const GhPullRequestGraphqlException({required final int errorCount}) extends GhPullRequestQueryException {
  @override
  String toString() => "GitHub pull request query returned $errorCount GraphQL error${errorCount == 1 ? "" : "s"}";
}

final class const GhPullRequestWrappedException({
    required final Object innerError,
    required final StackTrace innerStackTrace,
  }) extends GhPullRequestQueryException {
  @override
  String toString() => "GitHub pull request query failed while handling ${innerError.runtimeType}";
}

@Freezed(fromJson: true, toJson: true)
sealed class GhPullRequestBatchResponse with _$GhPullRequestBatchResponse {
  const factory({
    required int errorCount,
    required String viewerLogin,
    required List<GhPullRequestCandidatePage> pages,
  }) = _GhPullRequestBatchResponse;

  factory fromJson(Map<String, dynamic> json) => _$GhPullRequestBatchResponseFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class GhPullRequestCandidatePage with _$GhPullRequestCandidatePage {
  const factory({
    required int requestIndex,
    required GhPullRequestStateGroup stateGroup,
    required String repositoryIdentity,
    required GhPullRequestConnection connection,
  }) = _GhPullRequestCandidatePage;

  factory fromJson(Map<String, dynamic> json) => _$GhPullRequestCandidatePageFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class GhPullRequestConnection with _$GhPullRequestConnection {
  const factory({
    required List<GhPullRequest> nodes,
    required GhPullRequestPageInfo pageInfo,
  }) = _GhPullRequestConnection;

  factory fromJson(Map<String, dynamic> json) => _$GhPullRequestConnectionFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class GhPullRequestPageInfo with _$GhPullRequestPageInfo {
  const factory({
    required bool hasNextPage,
    required String? endCursor,
  }) = _GhPullRequestPageInfo;

  factory fromJson(Map<String, dynamic> json) => _$GhPullRequestPageInfoFromJson(json);
}
