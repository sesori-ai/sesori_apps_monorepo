import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Maps a [PluginProject] to the shared [Project] type used in relay responses.
///
/// [path] is the project's live directory (the stored path recorded at open
/// time, falling back to the id for never-moved projects); the plugin only
/// reports the stable id.
///
/// [time] is supplied from the persisted project activity DTO, not from the
/// plugin's `activity` or legacy `time` fields. The plugin's activity is only
/// used as evidence by the project-activity service.
extension PluginProjectMapper on PluginProject {
  Project toSharedProject({
    required String path,
    required bool hasUnseenChanges,
    required bool directoryMissing,
    required bool supportsDedicatedWorktrees,
    required ProjectTime? time,
  }) {
    return Project(
      id: id,
      name: name,
      path: path,
      time: time,
      hasUnseenChanges: hasUnseenChanges,
      directoryMissing: directoryMissing,
      supportsDedicatedWorktrees: supportsDedicatedWorktrees,
    );
  }
}
