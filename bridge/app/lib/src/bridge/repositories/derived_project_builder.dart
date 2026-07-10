import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginSession;
import "package:sesori_shared/sesori_shared.dart" show Project, ProjectTime;

import "../persistence/tables/projects_table.dart" show ProjectDto;

/// Derives the canonical project list for a bridge-derived plugin from its
/// sessions and the bridge's stored project rows. Pure transformation —
/// callers fetch the inputs.
///
/// This is the single home of the group-by-directory logic shared by Codex and
/// every future ACP plugin: the plugin only reports its sessions, and all
/// project shaping happens here. Each project's `id` is the normalized
/// directory — the canonical id the bridge persists and hands to the client, so
/// it must match the plugin's own `getSessions` filter (which normalizes the
/// same way). The `name` is the stored display-name override or the directory
/// basename, and the time comes from the project's sessions, falling back to
/// the stored row's openedAt for a folder with no sessions yet.
///
/// A session with a stored row groups under that row's project path
/// ([projectPathBySessionId], from the sessions⋈projects join) — which is how a
/// session running in a dedicated git worktree folds back under the project the
/// user opened instead of surfacing its worktree cwd as its own project. A
/// session without a row groups under its own directory.
class DerivedProjectBuilder {
  const DerivedProjectBuilder();

  List<Project> build({
    required List<PluginSession> sessions,
    required List<ProjectDto> storedProjects,
    required Map<String, String> projectPathBySessionId,
  }) {
    final accumulators = <String, _ProjectAccumulator>{};
    _ProjectAccumulator accumulatorFor(String directory) {
      final key = normalizeProjectDirectory(directory: directory);
      return accumulators.putIfAbsent(key, () => _ProjectAccumulator(id: key));
    }

    // Sessions are the primary source: each contributes its directory and times.
    for (final session in sessions) {
      final accumulator = accumulatorFor(projectPathBySessionId[session.id] ?? session.directory);
      final created = session.time?.created;
      final updated = session.time?.updated ?? created;
      if (created != null) {
        final prior = accumulator.created;
        accumulator.created = prior == null || created < prior ? created : prior;
      }
      if (updated != null) {
        final prior = accumulator.updated;
        accumulator.updated = prior == null || updated > prior ? updated : prior;
      }
    }

    // Every stored row is a project the bridge has recorded (opened folder,
    // rename, or a discovered session's FK target): it contributes its
    // display-name override and its openedAt as the time fallback for a folder
    // with no sessions.
    final displayNameByKey = <String, String?>{};
    for (final stored in storedProjects) {
      final key = normalizeProjectDirectory(directory: stored.path);
      displayNameByKey[key] = stored.displayName;
      accumulators.putIfAbsent(key, () => _ProjectAccumulator(id: key)).openedAt = stored.openedAt;
    }

    final projects = <Project>[];
    for (final accumulator in accumulators.values) {
      final override = displayNameByKey[accumulator.id];
      projects.add(
        Project(
          id: accumulator.id,
          name: override != null && override.isNotEmpty ? override : _basename(accumulator.id),
          // A derived project's id IS its normalized live directory.
          path: accumulator.id,
          time: ProjectTime(
            created: accumulator.created ?? accumulator.openedAt ?? 0,
            updated: accumulator.updated ?? accumulator.openedAt ?? 0,
            initialized: null,
          ),
        ),
      );
    }
    return projects;
  }

  String _basename(String directory) {
    final base = p.basename(directory);
    return base.isEmpty ? directory : base;
  }
}

/// Mutable scratch holder used while folding a directory's sessions and stored-
/// row facts into one [Project]. File-private and single-use.
class _ProjectAccumulator {
  _ProjectAccumulator({required this.id});

  final String id;
  int? created;
  int? updated;
  int? openedAt;
}
