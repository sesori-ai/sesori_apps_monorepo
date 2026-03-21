import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_project.freezed.dart";

part "plugin_project.g.dart";

@freezed
sealed class PluginProject with _$PluginProject {
  const factory PluginProject({
    required String id,
    String? name,
    PluginProjectTime? time,
  }) = _PluginProject;
}

@freezed
sealed class PluginProjectTime with _$PluginProjectTime {
  const factory PluginProjectTime({
    required int created,
    required int updated,
    int? initialized,
  }) = _PluginProjectTime;
}
