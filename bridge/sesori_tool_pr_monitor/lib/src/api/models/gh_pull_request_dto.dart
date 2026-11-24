import "package:freezed_annotation/freezed_annotation.dart";

part "gh_pull_request_dto.freezed.dart";
part "gh_pull_request_dto.g.dart";

// The GraphQL shapes [GhCliApi] asks for. Field nullability follows GitHub's
// schema. Open-ended enums fall back to `unknown` so a new GitHub value never
// fails a poll; the pull request state is a closed set.

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum GhPullRequestStateDto() {
  open,
  merged,
  closed,
}

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum GhMergeableStateDto() {
  mergeable,
  conflicting,
  unknown,
}

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum GhCheckStatusDto() {
  requested,
  queued,
  inProgress,
  waiting,
  pending,
  completed,
  unknown,
}

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum GhCheckConclusionDto() {
  success,
  neutral,
  skipped,
  failure,
  cancelled,
  timedOut,
  actionRequired,
  startupFailure,
  stale,
  unknown,
}

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum GhStatusStateDto() {
  success,
  pending,
  expected,
  error,
  failure,
  unknown,
}

@JsonEnum(fieldRename: FieldRename.screamingSnake)
enum GhReviewStateDto() {
  pending,
  commented,
  approved,
  changesRequested,
  dismissed,
  unknown,
}

enum GhActorKindDto() {
  @JsonValue("Bot")
  bot,
  other,
}

@Freezed(fromJson: true, toJson: false)
sealed class GhPullRequestDto with _$GhPullRequestDto {
  const factory({
    required String title,
    required String url,
    required GhPullRequestStateDto state,
    @JsonKey(unknownEnumValue: GhMergeableStateDto.unknown) required GhMergeableStateDto mergeable,
    required String headRefOid,
    required GhCommitConnectionDto commits,
    required GhReviewRequestConnectionDto reviewRequests,
    required GhReviewConnectionDto latestReviews,
    required GhReviewThreadConnectionDto reviewThreads,
    required GhIssueCommentConnectionDto comments,
    required GhLabelConnectionDto labels,
  }) = _GhPullRequestDto;

  factory fromJson(Map<String, dynamic> json) => _$GhPullRequestDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class GhPageInfoDto with _$GhPageInfoDto {
  const factory({required bool hasNextPage, required String? endCursor}) = _GhPageInfoDto;

  factory fromJson(Map<String, dynamic> json) => _$GhPageInfoDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class GhCommitConnectionDto with _$GhCommitConnectionDto {
  const factory({required List<GhCommitNodeDto> nodes}) = _GhCommitConnectionDto;

  factory fromJson(Map<String, dynamic> json) => _$GhCommitConnectionDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class GhCommitNodeDto with _$GhCommitNodeDto {
  const factory({required GhCommitDto commit}) = _GhCommitNodeDto;

  factory fromJson(Map<String, dynamic> json) => _$GhCommitNodeDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class GhCommitDto with _$GhCommitDto {
  /// [statusCheckRollup] is null when the commit has no checks at all.
  const factory({required GhStatusCheckRollupDto? statusCheckRollup}) = _GhCommitDto;

  factory fromJson(Map<String, dynamic> json) => _$GhCommitDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class GhStatusCheckRollupDto with _$GhStatusCheckRollupDto {
  const factory({required GhCheckContextConnectionDto contexts}) = _GhStatusCheckRollupDto;

  factory fromJson(Map<String, dynamic> json) => _$GhStatusCheckRollupDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class GhCheckContextConnectionDto with _$GhCheckContextConnectionDto {
  const factory({
    required GhPageInfoDto pageInfo,
    required List<GhCheckContextDto> nodes,
  }) = _GhCheckContextConnectionDto;

  factory fromJson(Map<String, dynamic> json) => _$GhCheckContextConnectionDtoFromJson(json);
}

@Freezed(unionKey: "__typename", fallbackUnion: "unknown", fromJson: true, toJson: false)
sealed class GhCheckContextDto with _$GhCheckContextDto {
  @FreezedUnionValue("CheckRun")
  const factory checkRun({
    required String id,
    required String name,
    @JsonKey(unknownEnumValue: GhCheckStatusDto.unknown) required GhCheckStatusDto status,
    @JsonKey(unknownEnumValue: GhCheckConclusionDto.unknown) required GhCheckConclusionDto? conclusion,
  }) = GhCheckRunDto;

  @FreezedUnionValue("StatusContext")
  const factory statusContext({
    required String context,
    @JsonKey(unknownEnumValue: GhStatusStateDto.unknown) required GhStatusStateDto state,
    required DateTime createdAt,
  }) = GhStatusContextDto;

  const factory unknown() = GhUnknownCheckContextDto;

  factory fromJson(Map<String, dynamic> json) => _$GhCheckContextDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class GhReviewRequestConnectionDto with _$GhReviewRequestConnectionDto {
  const factory({required List<GhReviewRequestDto> nodes}) = _GhReviewRequestConnectionDto;

  factory fromJson(Map<String, dynamic> json) => _$GhReviewRequestConnectionDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class GhReviewRequestDto with _$GhReviewRequestDto {
  const factory({required GhRequestedReviewerDto? requestedReviewer}) = _GhReviewRequestDto;

  factory fromJson(Map<String, dynamic> json) => _$GhReviewRequestDtoFromJson(json);
}

@Freezed(unionKey: "__typename", fallbackUnion: "unknown", fromJson: true, toJson: false)
sealed class GhRequestedReviewerDto with _$GhRequestedReviewerDto {
  @FreezedUnionValue("User")
  const factory user({required String login}) = GhRequestedUserDto;

  @FreezedUnionValue("Bot")
  const factory bot({required String login}) = GhRequestedBotDto;

  @FreezedUnionValue("Team")
  const factory team({required String slug}) = GhRequestedTeamDto;

  /// A mannequin or a reviewer kind GitHub adds later.
  const factory unknown() = GhUnknownRequestedReviewerDto;

  factory fromJson(Map<String, dynamic> json) => _$GhRequestedReviewerDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class GhReviewConnectionDto with _$GhReviewConnectionDto {
  const factory({
    required GhPageInfoDto pageInfo,
    required List<GhReviewDto> nodes,
  }) = _GhReviewConnectionDto;

  factory fromJson(Map<String, dynamic> json) => _$GhReviewConnectionDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class GhReviewDto with _$GhReviewDto {
  const factory({
    required String id,
    required GhActorDto? author,
    @JsonKey(unknownEnumValue: GhReviewStateDto.unknown) required GhReviewStateDto state,
    required DateTime? submittedAt,
    required String body,
    required GhTotalCountDto comments,
  }) = _GhReviewDto;

  factory fromJson(Map<String, dynamic> json) => _$GhReviewDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class GhReviewThreadConnectionDto with _$GhReviewThreadConnectionDto {
  const factory({
    required GhPageInfoDto pageInfo,
    required List<GhReviewThreadDto> nodes,
  }) = _GhReviewThreadConnectionDto;

  factory fromJson(Map<String, dynamic> json) => _$GhReviewThreadConnectionDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class GhReviewThreadDto with _$GhReviewThreadDto {
  const factory({
    required String id,
    required bool isResolved,
    required String? path,
    required int? line,
    required int? originalLine,
    required GhThreadCommentConnectionDto comments,
  }) = _GhReviewThreadDto;

  factory fromJson(Map<String, dynamic> json) => _$GhReviewThreadDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class GhThreadCommentConnectionDto with _$GhThreadCommentConnectionDto {
  const factory({required List<GhCommentDto> nodes}) = _GhThreadCommentConnectionDto;

  factory fromJson(Map<String, dynamic> json) => _$GhThreadCommentConnectionDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class GhIssueCommentConnectionDto with _$GhIssueCommentConnectionDto {
  const factory({
    required int totalCount,
    required List<GhCommentDto> nodes,
  }) = _GhIssueCommentConnectionDto;

  factory fromJson(Map<String, dynamic> json) => _$GhIssueCommentConnectionDtoFromJson(json);
}

/// An issue comment or a review-thread comment. Only thread comments carry
/// [pullRequestReview].
@Freezed(fromJson: true, toJson: false)
sealed class GhCommentDto with _$GhCommentDto {
  const factory({
    required String id,
    required GhActorDto? author,
    required String body,
    required DateTime createdAt,
    required GhCommentReviewDto? pullRequestReview,
  }) = _GhCommentDto;

  factory fromJson(Map<String, dynamic> json) => _$GhCommentDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class GhCommentReviewDto with _$GhCommentReviewDto {
  const factory({
    @JsonKey(unknownEnumValue: GhReviewStateDto.unknown) required GhReviewStateDto state,
  }) = _GhCommentReviewDto;

  factory fromJson(Map<String, dynamic> json) => _$GhCommentReviewDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class GhActorDto with _$GhActorDto {
  const factory({
    required String login,
    @JsonKey(name: "__typename", unknownEnumValue: GhActorKindDto.other) required GhActorKindDto kind,
  }) = _GhActorDto;

  factory fromJson(Map<String, dynamic> json) => _$GhActorDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class GhTotalCountDto with _$GhTotalCountDto {
  const factory({required int totalCount}) = _GhTotalCountDto;

  factory fromJson(Map<String, dynamic> json) => _$GhTotalCountDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class GhLabelConnectionDto with _$GhLabelConnectionDto {
  const factory({
    required GhPageInfoDto pageInfo,
    required List<GhLabelDto> nodes,
  }) = _GhLabelConnectionDto;

  factory fromJson(Map<String, dynamic> json) => _$GhLabelConnectionDtoFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class GhLabelDto with _$GhLabelDto {
  const factory({required String name}) = _GhLabelDto;

  factory fromJson(Map<String, dynamic> json) => _$GhLabelDtoFromJson(json);
}
