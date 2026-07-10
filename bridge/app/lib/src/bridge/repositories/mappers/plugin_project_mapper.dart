import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Maps a [PluginProject] to the shared [Project] type used in relay responses.
///
/// [path] is the project's live directory (the stored path recorded at open
/// time, falling back to the id for never-moved projects); the plugin only
/// reports the stable id.
extension PluginProjectMapper on PluginProject {
  Project toSharedProject({required String path, required bool hasUnseenChanges, required bool directoryMissing}) {
    return Project(
      id: id,
      name: name,
      path: path,
      time: switch (time) {
        PluginProjectTime(:final created, :final updated) => ProjectTime(
          created: created,
          updated: updated,
          initialized: null,
        ),
        null => null,
      },
      hasUnseenChanges: hasUnseenChanges,
      directoryMissing: directoryMissing,
    );
  }
}
