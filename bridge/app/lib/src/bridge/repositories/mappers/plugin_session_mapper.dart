import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Maps a [PluginSession] to the shared [Session] type used in relay responses.
extension PluginSessionMapper on PluginSession {
  Session toSharedSession() {
    return Session(
      id: id,
      projectID: projectID,
      directory: directory,
      parentID: parentID,
      title: title,
      branchName: null,
      time: switch (time) {
        PluginSessionTime(:final created, :final updated, :final archived) => SessionTime(
          created: created,
          updated: updated,
          archived: archived,
        ),
        null => null,
      },
      summary: switch (summary) {
        PluginSessionSummary(:final additions, :final deletions, :final files) => SessionSummary(
          additions: additions,
          deletions: deletions,
          files: files,
        ),
        null => null,
      },
      pullRequest: null,
    );
  }
}
