import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_project.freezed.dart";

part "plugin_project.g.dart";

/// A project as exposed to the bridge.
///
/// The [activity] field carries session-derived timestamps only; it is never
/// populated from upstream project metadata.
@freezed
sealed class PluginProject with _$PluginProject {
  const factory PluginProject({
    required String id,
    String? name,
    PluginProjectActivity? activity,
  }) = _PluginProject;
}

/// Session-derived activity bounds for a project.
///
/// The timestamps are computed from the root sessions that live under the
/// project's real or virtual worktree. If the project has no root sessions,
/// the activity is null.
@freezed
sealed class PluginProjectActivity with _$PluginProjectActivity {
  const factory PluginProjectActivity({
    required int createdAt,
    required int updatedAt,
  }) = _PluginProjectActivity;
}
