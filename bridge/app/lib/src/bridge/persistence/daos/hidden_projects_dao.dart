import "package:drift/drift.dart";

import "../database.dart";
import "../tables/hidden_projects.dart";

part "hidden_projects_dao.g.dart";

/// Data access object for the [HiddenProjects] table.
@DriftAccessor(tables: [HiddenProjects])
class HiddenProjectsDao extends DatabaseAccessor<AppDatabase> with _$HiddenProjectsDaoMixin {
  HiddenProjectsDao(super.attachedDatabase);

  /// Returns the set of all hidden project IDs.
  Future<Set<String>> getHiddenProjectIds() async {
    final rows = await select(hiddenProjects).get();
    return rows.map((r) => r.projectId).toSet();
  }

  /// Marks a project as hidden. Idempotent — hiding an already-hidden project is a no-op.
  Future<void> hideProject({required String projectId}) async {
    await into(hiddenProjects).insert(
      HiddenProjectsCompanion.insert(projectId: projectId),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Removes a project from the hidden list. No-op if the project is not hidden.
  Future<void> unhideProject({required String projectId}) async {
    await (delete(hiddenProjects)..where((t) => t.projectId.equals(projectId))).go();
  }
}
