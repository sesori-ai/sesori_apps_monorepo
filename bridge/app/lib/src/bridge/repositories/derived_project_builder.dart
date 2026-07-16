import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginSession;
import "package:sesori_shared/sesori_shared.dart" show Project;

import "../../api/database/tables/projects_table.dart" show ProjectDto;

/// Derives the canonical project list for a bridge-derived plugin from its
/// sessions and the bridge's stored project rows. Pure transformation —
/// callers fetch the inputs and decide how to persist the resulting evidence.
///
/// This is the single home of the group-by-directory logic shared by Codex and
/// every future ACP plugin: the plugin only reports its sessions, and all
/// project shaping happens here. Each project's `id` is the normalized
/// directory — the canonical id the bridge persists and hands to the client, so
/// it must match the plugin's own `getSessions` filter (which normalizes the
/// same way). The `name` is the stored display-name override or the directory
/// basename.
///
/// A session with a stored row groups under that row's project path
/// ([projectPathBySessionId], from the sessions⋈projects join) — which is how a
/// session running in a dedicated git worktree folds back under the project the
/// user opened instead of surfacing its worktree cwd as its own project. A
/// session without a row groups under its own directory.
///
/// The returned [Project] objects carry identity and name only; the repository
/// overlays the persisted activity timestamp before returning them to callers.
class DerivedProjectBuilder {
  const DerivedProjectBuilder();

  List<Project> build({
    required List<PluginSession> sessions,
    required List<ProjectDto> storedProjects,
    required Map<String, String> projectPathBySessionId,
  }) {
    final projectIds = <String>{};
    for (final session in sessions) {
      projectIds.add(
        normalizeProjectDirectory(directory: projectPathBySessionId[session.id] ?? session.directory),
      );
    }

    final displayNameByKey = <String, String?>{};
    for (final stored in storedProjects) {
      final key = normalizeProjectDirectory(directory: stored.path);
      displayNameByKey[key] = stored.displayName;
      // Ensure stored rows with no sessions still appear as projects.
      projectIds.add(key);
    }

    return [
      for (final id in projectIds)
        Project(
          id: id,
          name: switch (displayNameByKey[id]) {
            final override? when override.isNotEmpty => override,
            _ => _basename(id),
          },
          path: id,
          time: null,
        ),
    ];
  }

  String _basename(String directory) {
    final base = p.basename(directory);
    return base.isEmpty ? directory : base;
  }
}
