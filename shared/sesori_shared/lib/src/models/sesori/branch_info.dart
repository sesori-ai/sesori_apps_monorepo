import "package:freezed_annotation/freezed_annotation.dart";

part "branch_info.freezed.dart";

part "branch_info.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class BranchInfo with _$BranchInfo {
  const factory BranchInfo({
    required String name,
    required bool isRemoteOnly,
    required int? lastCommitTimestamp,
    required String? worktreePath,
  }) = _BranchInfo;

  factory BranchInfo.fromJson(Map<String, dynamic> json) => _$BranchInfoFromJson(json);
}
