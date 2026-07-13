import "package:path/path.dart" as p;
import "package:sesori_shared/sesori_shared.dart";

import "../../persistence/tables/projects_table.dart";

class ProjectCatalogMapper {
  const ProjectCatalogMapper();

  Project map({
    required ProjectDto row,
    required bool hasUnseenChanges,
    required bool directoryMissing,
  }) {
    final fallbackName = p.basename(row.path);
    return Project(
      id: row.projectId,
      name: row.displayName ?? row.catalogName ?? (fallbackName.isEmpty ? row.path : fallbackName),
      path: row.path,
      time: ProjectTime(created: row.createdAt, updated: row.updatedAt),
      hasUnseenChanges: hasUnseenChanges,
      directoryMissing: directoryMissing,
    );
  }
}
