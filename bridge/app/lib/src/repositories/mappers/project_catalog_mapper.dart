import "package:path/path.dart" as p;
import "package:sesori_shared/sesori_shared.dart";

import "../../api/database/tables/projects_table.dart";

class const ProjectCatalogMapper() {
  ProjectSummary mapSummary({
    required ProjectDto row,
    required bool hasUnseenChanges,
  }) {
    return ProjectSummary(
      id: row.projectId,
      name: _name(row),
      path: row.path,
      time: ProjectTime(created: row.createdAt, updated: row.updatedAt),
      hasUnseenChanges: hasUnseenChanges,
    );
  }

  Project mapProject({
    required ProjectDto row,
    required bool hasUnseenChanges,
    required bool directoryMissing,
    required bool supportsDedicatedWorktrees,
  }) {
    return Project(
      id: row.projectId,
      name: _name(row),
      path: row.path,
      time: ProjectTime(created: row.createdAt, updated: row.updatedAt),
      hasUnseenChanges: hasUnseenChanges,
      directoryMissing: directoryMissing,
      supportsDedicatedWorktrees: supportsDedicatedWorktrees,
    );
  }

  String _name(ProjectDto row) {
    final fallbackName = p.basename(row.path);
    return row.displayName ?? (fallbackName.isEmpty ? row.path : fallbackName);
  }
}
