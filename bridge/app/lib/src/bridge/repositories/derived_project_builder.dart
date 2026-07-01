import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginSession;
import "package:sesori_shared/sesori_shared.dart" show Project, ProjectTime;

import "../persistence/tables/projects_table.dart" show ProjectDto;
import "mappers/worktree_project_mapper.dart";

/// Derives the canonical project list for a bridge-derived plugin by grouping
/// its sessions by normalized directory and folding in the bridge-persisted
/// opened-folder and display-name overrides.
///
/// This is the single home of the group-by-directory logic shared by Codex and
/// every future ACP plugin: the plugin only reports its sessions, and all
/// project shaping happens here. Each project's `id` is the normalized
/// directory — the canonical id the bridge persists and hands to the client, so
/// it must match the plugin's own `getSessions` filter (which normalizes the
/// same way). The `name` is the stored display-name override
/// or the directory basename, and the time comes from the project's sessions,
/// falling back to the opened-folder timestamp for a folder with no sessions
/// yet.
///
/// A session running in a dedicated git worktree reports the worktree path as
/// its directory; [worktreeMapper] folds it back to the project the user opened
/// so a worktree does not surface as its own project.
class DerivedProjectBuilder {
  const DerivedProjectBuilder();

  List<Project> build({
    required List<PluginSession> sessions,
    required List<ProjectDto> storedProjects,
    required WorktreeProjectMapper worktreeMapper,
  }) {
    final accumulators = <String, _ProjectAccumulator>{};
    _ProjectAccumulator accumulatorFor(String directory) {
      final key = worktreeMapper.canonicalDirectory(directory);
      return accumulators.putIfAbsent(key, () => _ProjectAccumulator(id: key));
    }

    // Sessions are the primary source: each contributes its directory and times.
    for (final session in sessions) {
      final accumulator = accumulatorFor(session.directory);
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

    // Stored rows contribute display-name overrides (always) and opened-but-
    // empty folders (a row with openedAt set but no sessions). A bare FK
    // placeholder row — no openedAt, no sessions — is intentionally NOT listed.
    final displayNameByKey = <String, String?>{};
    for (final stored in storedProjects) {
      final key = worktreeMapper.canonicalDirectory(stored.projectId);
      displayNameByKey[key] = stored.displayName;
      final openedAt = stored.openedAt;
      if (openedAt != null) {
        accumulators.putIfAbsent(key, () => _ProjectAccumulator(id: key)).openedAt = openedAt;
      }
    }

    final projects = <Project>[];
    for (final accumulator in accumulators.values) {
      final override = displayNameByKey[accumulator.id];
      projects.add(
        Project(
          id: accumulator.id,
          name: override != null && override.isNotEmpty ? override : _basename(accumulator.id),
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

/// Mutable scratch holder used while folding a directory's sessions and opened-
/// folder facts into one [Project]. File-private and single-use.
class _ProjectAccumulator {
  _ProjectAccumulator({required this.id});

  final String id;
  int? created;
  int? updated;
  int? openedAt;
}
