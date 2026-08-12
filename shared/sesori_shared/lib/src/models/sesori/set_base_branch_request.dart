import "package:freezed_annotation/freezed_annotation.dart";

part "set_base_branch_request.freezed.dart";
part "set_base_branch_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class SetBaseBranchRequest with _$SetBaseBranchRequest {
  const factory({
    required String projectId,
    required String baseBranch,
  }) = _SetBaseBranchRequest;

  factory fromJson(Map<String, dynamic> json) => _$SetBaseBranchRequestFromJson(json);
}
