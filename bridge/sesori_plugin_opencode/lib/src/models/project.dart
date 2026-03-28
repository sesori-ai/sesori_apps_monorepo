import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

part "project.freezed.dart";

part "project.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class Project with _$Project {
  const factory Project({
    required String id,
    required String worktree,
    String? name,
    ProjectTime? time,
  }) = _Project;

  factory Project.fromJson(Map<String, dynamic> json) => _$ProjectFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class ProjectTime with _$ProjectTime {
  const factory ProjectTime({
    required int created,
    required int updated,
    int? initialized,
  }) = _ProjectTime;

  factory ProjectTime.fromJson(Map<String, dynamic> json) => _$ProjectTimeFromJson(json);
}

extension ProjectToPluginExtension on Project {
  PluginProject toPlugin() => PluginProject(
    id: worktree, // worktree is the most reliable UID with opencode
    name: _effectiveName,
    time: switch (time) {
      ProjectTime(:final created, :final updated) => PluginProjectTime(
        created: created,
        updated: updated,
      ),
      null => null,
    },
  );

  /// Returns [name] when present and non-empty, otherwise extracts the
  /// directory name from [worktree] as a fallback. OpenCode can return an
  /// empty name after project metadata is edited through its web UI.
  String? get _effectiveName {
    final n = name;
    if (n != null && n.isNotEmpty) return n;
    if (worktree.isEmpty) return null;
    final normalized = worktree.replaceAll(r"\", "/");
    final segments = normalized.split("/").where((s) => s.isNotEmpty);
    return segments.isEmpty ? null : segments.last;
  }
}
