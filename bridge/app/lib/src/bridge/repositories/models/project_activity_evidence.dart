import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginProjectActivity, PluginSessionTime;

/// Uncombined activity timestamps reported for one project.
class ProjectActivityEvidence {
  const ProjectActivityEvidence({
    required this.pluginId,
    required this.projectId,
    required this.pluginActivity,
    required this.sessionActivities,
  });

  final String pluginId;
  final String projectId;
  final PluginProjectActivity? pluginActivity;
  final List<PluginSessionTime> sessionActivities;
}
