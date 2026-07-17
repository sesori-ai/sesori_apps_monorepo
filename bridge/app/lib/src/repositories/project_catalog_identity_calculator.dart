import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;

import "../api/database/tables/projects_table.dart" show ProjectDto;

/// Selects the existing catalog row that owns an observed plugin project.
class ProjectCatalogIdentityCalculator {
  const ProjectCatalogIdentityCalculator();

  /// Prefers the stable plugin-supplied id, then the normalized observed path.
  /// Returns null when neither signal identifies an existing catalog row.
  ProjectDto? calculate({
    required Iterable<ProjectDto> existingProjects,
    required String preferredProjectId,
    required String observedPath,
  }) {
    for (final project in existingProjects) {
      if (project.projectId == preferredProjectId) return project;
    }

    final normalizedObservedPath = normalizeProjectDirectory(directory: observedPath);
    for (final project in existingProjects) {
      if (normalizeProjectDirectory(directory: project.path) == normalizedObservedPath) return project;
    }
    return null;
  }
}
