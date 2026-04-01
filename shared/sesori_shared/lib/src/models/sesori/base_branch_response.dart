import "package:freezed_annotation/freezed_annotation.dart";

part "base_branch_response.freezed.dart";
part "base_branch_response.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class BaseBranchResponse with _$BaseBranchResponse {
  const factory BaseBranchResponse({
    required String? baseBranch,
  }) = _BaseBranchResponse;

  factory BaseBranchResponse.fromJson(Map<String, dynamic> json) => _$BaseBranchResponseFromJson(json);
}
