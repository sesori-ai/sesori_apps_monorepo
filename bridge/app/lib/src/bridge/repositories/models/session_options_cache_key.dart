import "package:meta/meta.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

@immutable
sealed class const SessionOptionsCacheKey({required final String pluginId}) {
  const factory plugin({
    required String pluginId,
  }) = PluginSessionOptionsCacheKey;

  const factory project({
    required String pluginId,
    required String projectId,
    required String projectPath,
  }) = ProjectSessionOptionsCacheKey;

  PluginSessionOptionsScope get scope;

  String get ownerId;
}

final class const PluginSessionOptionsCacheKey({required super.pluginId}) extends SessionOptionsCacheKey {
  this : assert(pluginId != "");

  @override
  PluginSessionOptionsScope get scope => PluginSessionOptionsScope.plugin;

  @override
  String get ownerId => pluginId;

  @override
  bool operator ==(Object other) => other is PluginSessionOptionsCacheKey && other.pluginId == pluginId;

  @override
  int get hashCode => Object.hash(PluginSessionOptionsCacheKey, pluginId);
}

final class const ProjectSessionOptionsCacheKey({
  required super.pluginId,
  required final String projectId,
  required final String projectPath,
}) extends SessionOptionsCacheKey {
  this : assert(pluginId != ""), assert(projectId != ""), assert(projectPath != "");

  @override
  PluginSessionOptionsScope get scope => PluginSessionOptionsScope.project;

  @override
  String get ownerId => projectId;

  @override
  bool operator ==(Object other) {
    return other is ProjectSessionOptionsCacheKey &&
        other.pluginId == pluginId &&
        other.projectId == projectId &&
        other.projectPath == projectPath;
  }

  @override
  int get hashCode => Object.hash(ProjectSessionOptionsCacheKey, pluginId, projectId, projectPath);
}
