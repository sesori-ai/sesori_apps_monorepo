import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginSession, PluginSessionTime;
import "package:sesori_shared/sesori_shared.dart" show Project;

import "../persistence/tables/projects_table.dart" show ProjectDto;

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
/// The paired session times remain uncombined so the activity service owns all
/// timestamp ordering decisions.
class DerivedProjectBuilder {
  const DerivedProjectBuilder();

  List<({Project project, List<PluginSessionTime> sessionActivities})> build({
    required List<PluginSession> sessions,
    required List<ProjectDto> storedProjects,
    required Map<String, String> projectPathBySessionId,
  }) {
    final accumulators = <String, _ProjectAccumulator>{};
    _ProjectAccumulator accumulatorFor(String directory) {
      final key = normalizeProjectDirectory(directory: directory);
      return accumulators.putIfAbsent(key, () => _ProjectAccumulator(id: key));
    }

    for (final session in sessions) {
      final accumulator = accumulatorFor(projectPathBySessionId[session.id] ?? session.directory);
      final time = session.time;
      if (time == null) continue;
      accumulator.sessionTimes.add(time);
    }

    final displayNameByKey = <String, String?>{};
    for (final stored in storedProjects) {
      final key = normalizeProjectDirectory(directory: stored.path);
      displayNameByKey[key] = stored.displayName;
      // Ensure stored rows with no sessions still appear as projects.
      accumulators.putIfAbsent(key, () => _ProjectAccumulator(id: key));
    }

    final results = <({Project project, List<PluginSessionTime> sessionActivities})>[];
    for (final accumulator in accumulators.values) {
      final override = displayNameByKey[accumulator.id];
      results.add((
        project: Project(
          id: accumulator.id,
          name: override != null && override.isNotEmpty ? override : _basename(accumulator.id),
          path: accumulator.id,
          time: null,
        ),
        sessionActivities: List.unmodifiable(accumulator.sessionTimes),
      ));
    }
    return results;
  }

  String _basename(String directory) {
    final base = p.basename(directory);
    return base.isEmpty ? directory : base;
  }
}

class _ProjectAccumulator {
  _ProjectAccumulator({required this.id});

  final String id;
  final List<PluginSessionTime> sessionTimes = [];
}
