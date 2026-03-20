import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_project_activity_summary.freezed.dart";
part "plugin_project_activity_summary.g.dart";

@freezed
sealed class PluginProjectActivitySummary with _$PluginProjectActivitySummary {
  const factory PluginProjectActivitySummary({
    required String worktree,
    required int activeSessions,
    @Default([]) List<String> activeSessionIds,
  }) = _PluginProjectActivitySummary;
}
