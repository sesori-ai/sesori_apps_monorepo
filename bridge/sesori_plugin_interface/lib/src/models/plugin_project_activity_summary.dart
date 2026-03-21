import "package:freezed_annotation/freezed_annotation.dart";

import "plugin_active_session.dart";

part "plugin_project_activity_summary.freezed.dart";
part "plugin_project_activity_summary.g.dart";

@freezed
sealed class PluginProjectActivitySummary with _$PluginProjectActivitySummary {
  const factory PluginProjectActivitySummary({
    required String id,
    required List<PluginActiveSession> activeSessions,
  }) = _PluginProjectActivitySummary;
}
