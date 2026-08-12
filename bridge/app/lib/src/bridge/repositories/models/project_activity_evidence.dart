import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginProjectActivity, PluginSessionTime;

/// Uncombined activity timestamps reported for one project.
class const ProjectActivityEvidence({
  required final String pluginId,
  required final String projectId,
  required final PluginProjectActivity? pluginActivity,
  required final List<PluginSessionTime> sessionActivities,
});
