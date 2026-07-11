import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginProjectActivity, PluginSessionTime;

import "project_activity.dart";

/// Uncombined activity timestamps reported for one project.
class ProjectActivityEvidence {
  const ProjectActivityEvidence({
    required this.projectId,
    required this.pluginActivity,
    required this.sessionActivities,
  });

  final String projectId;
  final PluginProjectActivity? pluginActivity;
  final List<PluginSessionTime> sessionActivities;
}

class ProjectActivityReconciliationData {
  const ProjectActivityReconciliationData({required this.evidence, required this.storedActivities});

  final List<ProjectActivityEvidence> evidence;
  final Map<String, ProjectActivity> storedActivities;
}
