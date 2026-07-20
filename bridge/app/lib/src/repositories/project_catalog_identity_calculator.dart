import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;

import "../api/database/tables/projects_table.dart" show ProjectDto;

/// Selects the existing catalog row that owns an observed plugin project.
class ProjectCatalogIdentityCalculator {
  const ProjectCatalogIdentityCalculator();

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

  /// Prefers the stable plugin-supplied id, then the normalized observed path.
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
}
