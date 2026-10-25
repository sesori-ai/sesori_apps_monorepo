import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart"
    show normalizeProjectDirectory, normalizeProjectDirectoryWithContext;

import "../api/database/tables/projects_table.dart" show ProjectDto;

/// Selects the existing bridge-owned catalog row for an observed project, and
/// owns the one rule for which paths belong to the scratch root that holds
/// project-less sessions' folders.
///
/// [_pathContext] is the host's path style in production. The scratch rule
/// takes it explicitly so its Windows behavior is testable on every host.
class ProjectCatalogIdentityCalculator({
  required final String _scratchRoot,
  required final p.Context _pathContext,
}) {
  /// Indexes projects by normalized path. When legacy rows collide, the row
  /// with the lexicographically smallest project id is the stable winner.
  Map<String, ProjectDto> buildProjectsByNormalizedPath({
    required Iterable<ProjectDto> projects,
  }) {
    final result = <String, ProjectDto>{};
    for (final project in projects) {
      final normalizedPath = normalizeProjectDirectory(directory: project.path);
      final existing = result[normalizedPath];
      if (existing == null || project.projectId.compareTo(existing.projectId) < 0) {
        result[normalizedPath] = project;
      }
    }
    return result;
  }

  /// Prefers the supplied durable id, then the normalized observed path.
  /// Returns null when neither signal identifies an existing catalog row.
  ProjectDto? calculate({
    required Map<String, ProjectDto> projectsById,
    required Map<String, ProjectDto> projectsByNormalizedPath,
    required String preferredProjectId,
    required String observedPath,
  }) {
    return projectsById[preferredProjectId] ??
        projectsByNormalizedPath[normalizeProjectDirectory(directory: observedPath)];
  }

  /// Whether [path] names the scratch root itself.
  bool isScratchRoot({required String path}) {
    return _pathContext.equals(_normalize(path: path), _normalize(path: _scratchRoot));
  }

  /// Whether [path] is the scratch root or lies anywhere inside it.
  bool isWithinScratch({required String path}) {
    final root = _normalize(path: _scratchRoot);
    final normalizedPath = _normalize(path: path);
    return _pathContext.equals(root, normalizedPath) || _pathContext.isWithin(root, normalizedPath);
  }

  /// Whether [path] names one session folder: a direct child of the scratch
  /// root, spelled without `..` segments.
  ///
  /// A `..` segment is refused rather than resolved, because a path that has
  /// to climb back up never came from the bridge's own folder creation.
  bool isScratchSessionDirectory({required String path}) {
    if (_pathContext.split(path).contains("..")) return false;
    return isScratchRoot(path: _pathContext.dirname(_normalize(path: path)));
  }

  String _normalize({required String path}) =>
      normalizeProjectDirectoryWithContext(pathContext: _pathContext, directory: path);
}
