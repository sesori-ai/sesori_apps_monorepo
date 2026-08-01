import "package:freezed_annotation/freezed_annotation.dart";

import "../bridge/api/gh_pull_request.dart";

part "gh_pull_request_batch.freezed.dart";
part "gh_pull_request_batch.g.dart";

enum GhPullRequestStateGroup { open, terminal }

final class GhPullRequestTarget {
  final String repositoryOwner;
  final String repositoryName;
  final String branchName;

  const GhPullRequestTarget({
    required this.repositoryOwner,
    required this.repositoryName,
    required this.branchName,
  });
}

final class GhPullRequestCursorRequest {
  final GhPullRequestTarget target;
  final GhPullRequestStateGroup stateGroup;
  final String cursor;

  const GhPullRequestCursorRequest({
    required this.target,
    required this.stateGroup,
    required this.cursor,
  });
}

sealed class GhPullRequestQueryException implements Exception {
  const GhPullRequestQueryException();

  @override
  String toString() => "GitHub pull request query failed";
}

final class GhPullRequestProcessExitException extends GhPullRequestQueryException {
  final int exitCode;

  const GhPullRequestProcessExitException({required this.exitCode});
}

final class GhPullRequestGraphqlException extends GhPullRequestQueryException {
  final int errorCount;

  const GhPullRequestGraphqlException({required this.errorCount});
}

final class GhPullRequestWrappedException extends GhPullRequestQueryException {
  final Object innerError;
  final StackTrace innerStackTrace;

  const GhPullRequestWrappedException({
    required this.innerError,
    required this.innerStackTrace,
  });
}

@Freezed(fromJson: true, toJson: true)
sealed class GhPullRequestBatchResponse with _$GhPullRequestBatchResponse {
  const factory GhPullRequestBatchResponse({
    required int errorCount,
    required String viewerLogin,
    required List<GhPullRequestCandidatePage> pages,
  }) = _GhPullRequestBatchResponse;

  factory GhPullRequestBatchResponse.fromJson(Map<String, dynamic> json) => _$GhPullRequestBatchResponseFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class GhPullRequestCandidatePage with _$GhPullRequestCandidatePage {
  const factory GhPullRequestCandidatePage({
    required int requestIndex,
    required GhPullRequestStateGroup stateGroup,
    required String repositoryIdentity,
    required GhPullRequestConnection connection,
  }) = _GhPullRequestCandidatePage;

  factory GhPullRequestCandidatePage.fromJson(Map<String, dynamic> json) => _$GhPullRequestCandidatePageFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class GhPullRequestConnection with _$GhPullRequestConnection {
  const factory GhPullRequestConnection({
    required List<GhPullRequest> nodes,
    required GhPullRequestPageInfo pageInfo,
  }) = _GhPullRequestConnection;

  factory GhPullRequestConnection.fromJson(Map<String, dynamic> json) => _$GhPullRequestConnectionFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class GhPullRequestPageInfo with _$GhPullRequestPageInfo {
  const factory GhPullRequestPageInfo({
    required bool hasNextPage,
    required String? endCursor,
  }) = _GhPullRequestPageInfo;

  factory GhPullRequestPageInfo.fromJson(Map<String, dynamic> json) => _$GhPullRequestPageInfoFromJson(json);
}
