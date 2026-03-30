import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Maps a [PluginProject] to the shared [Project] type used in relay responses.
extension PluginProjectMapper on PluginProject {
  Project toSharedProject() {
    return Project(
      id: id,
      name: name,
      time: switch (time) {
        PluginProjectTime(:final created, :final updated) => ProjectTime(
          created: created,
          updated: updated,
          initialized: null,
        ),
        null => null,
      },
    );
  }
}
