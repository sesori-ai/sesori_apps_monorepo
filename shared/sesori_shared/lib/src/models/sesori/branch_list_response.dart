import "package:freezed_annotation/freezed_annotation.dart";

import "branch_info.dart";

part "branch_list_response.freezed.dart";

part "branch_list_response.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class BranchListResponse with _$BranchListResponse {
  const factory BranchListResponse({
    required List<BranchInfo> branches,
    required String? currentBranch,
  }) = _BranchListResponse;

  factory BranchListResponse.fromJson(Map<String, dynamic> json) => _$BranchListResponseFromJson(json);
}
