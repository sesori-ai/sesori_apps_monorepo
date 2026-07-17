import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;

import "../api/database/tables/projects_table.dart" show ProjectDto;

/// Selects the existing catalog row that owns an observed plugin project.
class ProjectCatalogIdentityCalculator {
  const ProjectCatalogIdentityCalculator();

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
