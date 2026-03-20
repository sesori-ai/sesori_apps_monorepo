import "package:freezed_annotation/freezed_annotation.dart";

part "project_activity_summary.freezed.dart";
part "project_activity_summary.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class ProjectActivitySummary with _$ProjectActivitySummary {
  const factory ProjectActivitySummary({
    required String id,
    required List<String> activeSessionIds,
  }) = _ProjectActivitySummary;

  factory ProjectActivitySummary.fromJson(Map<String, dynamic> json) => _$ProjectActivitySummaryFromJson(json);
}
