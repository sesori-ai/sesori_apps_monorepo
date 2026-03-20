import "package:freezed_annotation/freezed_annotation.dart";

part "project_activity_summary.freezed.dart";
part "project_activity_summary.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class ProjectActivitySummary with _$ProjectActivitySummary {
  const factory ProjectActivitySummary({
    required String worktree,
    @Default(0) int activeSessions,
    @Default([]) List<String> activeSessionIds,
  }) = _ProjectActivitySummary;

  factory ProjectActivitySummary.fromJson(Map<String, dynamic> json) => _$ProjectActivitySummaryFromJson(json);
}
