import "package:freezed_annotation/freezed_annotation.dart";

part "gh_pull_request.freezed.dart";
part "gh_pull_request.g.dart";

String? _extractRollupState(Object? value) {
  return switch (value) {
    null => null,
    final String stringValue => stringValue,
    final Map<String, dynamic> object => object["state"]?.toString() ?? object["conclusion"]?.toString(),
    _ => null,
  };
}

@Freezed(fromJson: true, toJson: true)
sealed class GhPullRequest with _$GhPullRequest {
  const factory GhPullRequest({
    required int number,
    required String url,
    required String title,
    required String state,
    required String headRefName,
    required String? mergeable,
    required String? reviewDecision,
    @JsonKey(fromJson: _extractRollupState) required String? statusCheckRollup,
  }) = _GhPullRequest;

  factory GhPullRequest.fromJson(Map<String, dynamic> json) => _$GhPullRequestFromJson(json);
}
