import "package:drift/drift.dart";

import "../database.dart";
import "../tables/projects_table.dart";

part "projects_dao.g.dart";

@DriftAccessor(tables: [ProjectsTable])
class ProjectsDao extends DatabaseAccessor<AppDatabase> with _$ProjectsDaoMixin {
  ProjectsDao(super.attachedDatabase);

  /// Returns the set of all currently hidden project IDs (one-shot).
  Future<Set<String>> getHiddenProjectIds() async {
    final rows = await (select(projectsTable)..where((t) => t.hidden.equals(true))).get();
    return rows.map((r) => r.projectId).toSet();
  }

  /// Watches the set of hidden project IDs reactively.
  Stream<Set<String>> get hiddenProjectIdsStream {
    return (select(
      projectsTable,
    )..where((t) => t.hidden.equals(true))).watch().map((rows) => rows.map((r) => r.projectId).toSet());
  }

  /// Marks a project as hidden. Idempotent.
  Future<void> hideProject({required String projectId}) async {
    await into(projectsTable).insertOnConflictUpdate(
      ProjectsTableCompanion.insert(projectId: projectId, hidden: const Value(true)),
    );
  }

  /// Removes the hidden flag from a project. No-op if not hidden.
  Future<void> unhideProject({required String projectId}) async {
    await (update(projectsTable)..where((t) => t.projectId.equals(projectId))).write(
      const ProjectsTableCompanion(hidden: Value(false)),
    );
  }
}
