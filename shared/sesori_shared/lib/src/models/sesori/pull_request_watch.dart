import "package:freezed_annotation/freezed_annotation.dart";

part "pull_request_watch.freezed.dart";
part "pull_request_watch.g.dart";

/// A GitHub pull request the bridge's PR monitor watches for a root session.
@Freezed(fromJson: true, toJson: true)
sealed class SessionPullRequestWatch with _$SessionPullRequestWatch {
  const factory({
    /// `owner/repo`.
    required String repository,
    required int number,

    /// The PR's title at the watch's last report.
    required String title,
    required String url,

    /// Whether this session's watch merges the PR once it is ready.
    required bool autoMerge,
    required PullRequestWatchStatus status,
  }) = _SessionPullRequestWatch;

  factory fromJson(Map<String, dynamic> json) => _$SessionPullRequestWatchFromJson(json);
}

/// Where a watched PR stands, as far as the user is concerned.
@Freezed(unionKey: "kind", fallbackUnion: "unknown", fromJson: true, toJson: true)
sealed class PullRequestWatchStatus with _$PullRequestWatchStatus {
  /// A kind this build does not know.
  const factory unknown() = PullRequestWatchStatusUnknown;

  /// The PR needs the user, for every reason in the non-empty [reasons].
  const factory needsYou({
    @JsonKey(unknownEnumValue: PullRequestWatchNeed.unknown) required List<PullRequestWatchNeed> reasons,
  }) = PullRequestWatchStatusNeedsYou;

  /// Open, with nothing for the user to do yet.
  const factory waiting() = PullRequestWatchStatusWaiting;

  /// Marked ready, and auto-merge will merge it.
  const factory ready() = PullRequestWatchStatusReady;

  /// Merged at [mergedAt], in UTC milliseconds. It stays listed until the
  /// bridge's local midnight.
  const factory merged({required int mergedAt}) = PullRequestWatchStatusMerged;

  factory fromJson(Map<String, dynamic> json) => _$PullRequestWatchStatusFromJson(json);
}

/// Why a watched PR needs the user.
enum PullRequestWatchNeed() {
  /// A reason this build does not know.
  unknown,
  ciFailing,
  conflict,

  /// Review feedback has no `[Sesori reply]` yet.
  newReviewComments,

  /// Marked ready, but no watch merges it, so a human has to.
  readyWithoutAutoMerge,
}

/// `GET /pull-request-watches`: every PR this bridge watches, for any
/// session, merged ones included until local midnight.
@Freezed(fromJson: true, toJson: true)
sealed class PullRequestWatchListResponse with _$PullRequestWatchListResponse {
  const factory({required List<PullRequestWatchListItem> watches}) = _PullRequestWatchListResponse;

  factory fromJson(Map<String, dynamic> json) => _$PullRequestWatchListResponseFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class PullRequestWatchListItem with _$PullRequestWatchListItem {
  const factory({
    /// The root session that watches the PR.
    required String sessionId,
    required String? sessionTitle,
    required String projectId,
    required SessionPullRequestWatch watch,
  }) = _PullRequestWatchListItem;

  factory fromJson(Map<String, dynamic> json) => _$PullRequestWatchListItemFromJson(json);
}

/// Request body for `POST /session/pull-request-watch/stop`, which answers
/// with the updated session. The agent is not told. A watch that already
/// ended answers the same way.
@Freezed(fromJson: true, toJson: true)
sealed class StopPullRequestWatchRequest with _$StopPullRequestWatchRequest {
  const factory({
    /// The root session that watches the PR.
    required String sessionId,

    /// `owner/repo`.
    required String repository,
    required int number,
  }) = _StopPullRequestWatchRequest;

  factory fromJson(Map<String, dynamic> json) => _$StopPullRequestWatchRequestFromJson(json);
}

/// Request body for `POST /session/pull-request-watch/auto-merge`: turns
/// auto-merge on or off for one session's watch, and answers with the updated
/// session. The agent is not told.
@Freezed(fromJson: true, toJson: true)
sealed class SetPullRequestWatchAutoMergeRequest with _$SetPullRequestWatchAutoMergeRequest {
  const factory({
    /// The root session that watches the PR.
    required String sessionId,

    /// `owner/repo`.
    required String repository,
    required int number,
    required bool enabled,
  }) = _SetPullRequestWatchAutoMergeRequest;

  factory fromJson(Map<String, dynamic> json) => _$SetPullRequestWatchAutoMergeRequestFromJson(json);
}
