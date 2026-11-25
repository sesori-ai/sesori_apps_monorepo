import "package:freezed_annotation/freezed_annotation.dart";

part "gh_rest_pull_request_dto.freezed.dart";
part "gh_rest_pull_request_dto.g.dart";

// The REST shapes [GhCliApi] reads around a merge.

enum GhRestPullRequestStateDto() {
  open,
  closed,
}

/// `GET repos/{owner}/{repo}/pulls/{number}`: a merged PR is `closed` with
/// [merged] set.
@Freezed(fromJson: true, toJson: false)
sealed class GhRestPullRequestDto with _$GhRestPullRequestDto {
  const factory({
    required GhRestPullRequestStateDto state,
    required bool merged,
    required String title,
    required GhRestHeadDto head,
  }) = _GhRestPullRequestDto;

  factory fromJson(Map<String, dynamic> json) => _$GhRestPullRequestDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class GhRestHeadDto with _$GhRestHeadDto {
  const factory({required String sha}) = _GhRestHeadDto;

  factory fromJson(Map<String, dynamic> json) => _$GhRestHeadDtoFromJson(json);
}

/// `PUT repos/{owner}/{repo}/pulls/{number}/merge`.
@Freezed(fromJson: true, toJson: false)
sealed class GhMergeResultDto with _$GhMergeResultDto {
  const factory({required bool? merged, required String? message}) = _GhMergeResultDto;

  factory fromJson(Map<String, dynamic> json) => _$GhMergeResultDtoFromJson(json);
}
