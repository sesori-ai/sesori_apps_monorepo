import "package:freezed_annotation/freezed_annotation.dart";

import "pull_request_baseline.dart";

part "stored_pull_request_watch.freezed.dart";
part "stored_pull_request_watch.g.dart";

/// One session's watch of one PR, as stored to resume after a restart.
@freezed
sealed class StoredPullRequestWatch with _$StoredPullRequestWatch {
  const factory({
    required String owner,
    required String repo,
    required int number,

    /// The PR's title at the last report, for lists.
    required String title,
    required bool autoMerge,

    /// What the last report to this session covered.
    required PullRequestBaseline baseline,
    required DateTime lastReportAt,
  }) = _StoredPullRequestWatch;

  factory fromJson(Map<String, dynamic> json) => _$StoredPullRequestWatchFromJson(json);
}
