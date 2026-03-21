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
    id: id,
    worktree: worktree,
    name: name,
    time: switch (time) {
      ProjectTime(:final created, :final updated) => PluginProjectTime(
        created: created,
        updated: updated,
      ),
      null => null,
    },
  );
}
