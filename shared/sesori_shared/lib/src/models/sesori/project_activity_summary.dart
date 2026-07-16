import "package:freezed_annotation/freezed_annotation.dart";

import "active_session.dart";

part "project_activity_summary.freezed.dart";
part "project_activity_summary.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class ProjectActivitySummary with _$ProjectActivitySummary {
  /// A project's current active work.
  ///
  /// When the containing `projects.summary` declares
  /// `userInteractionOrdered`, [activeSessions] is ordered by the bridge and
  /// consumers must preserve that order.
  const factory ProjectActivitySummary({
    required String id,
    required List<ActiveSession> activeSessions,
  }) = _ProjectActivitySummary;

  factory ProjectActivitySummary.fromJson(Map<String, dynamic> json) => _$ProjectActivitySummaryFromJson(json);
}
