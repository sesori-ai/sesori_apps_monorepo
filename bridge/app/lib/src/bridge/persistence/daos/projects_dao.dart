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

  /// Removes the hidden flag from a project. Creates the row if missing.
  /// Uses DoUpdate to update ONLY the hidden column on conflict, preserving
  /// baseBranch and worktreeCounter on existing rows.
  Future<void> unhideProject({required String projectId}) async {
    await into(projectsTable).insert(
      ProjectsTableCompanion.insert(projectId: projectId, hidden: const Value(false)),
      onConflict: DoUpdate(
        (old) => ProjectsTableCompanion(hidden: const Value(false)),
        target: [projectsTable.projectId],
      ),
    );
  }

  /// Atomically increments the worktree counter for a project and returns the new value.
  ///
  /// If no row exists for [projectId], inserts one with counter=1.
  /// If a row exists, increments its counter by 1.
  /// Preserves existing [hidden] and [baseBranch] values.
  Future<int> incrementAndGetWorktreeCounter({required String projectId}) async {
    return transaction(() async {
      final existing = await (select(projectsTable)..where((t) => t.projectId.equals(projectId))).getSingleOrNull();
      if (existing != null) {
        final newCounter = existing.worktreeCounter + 1;
        await (update(projectsTable)..where((t) => t.projectId.equals(projectId))).write(
          ProjectsTableCompanion(worktreeCounter: Value(newCounter)),
        );
        return newCounter;
      } else {
        await into(projectsTable).insert(
          ProjectsTableCompanion.insert(projectId: projectId, worktreeCounter: const Value(1)),
        );
        return 1;
      }
    });
  }

  /// Returns the base branch for the given project, or null if no row exists.
  Future<String?> getBaseBranch({required String projectId}) async {
    final row = await (select(projectsTable)..where((t) => t.projectId.equals(projectId))).getSingleOrNull();
    return row?.baseBranch;
  }

  /// Sets the base branch for the given project.
  ///
  /// If no row exists, inserts one with the given [baseBranch].
  /// If a row exists, updates only [baseBranch], preserving [hidden] and [worktreeCounter].
  Future<void> setBaseBranch({required String projectId, required String? baseBranch}) async {
    await into(projectsTable).insertOnConflictUpdate(
      ProjectsTableCompanion.insert(projectId: projectId, baseBranch: Value(baseBranch)),
    );
  }

  /// Inserts a minimal project row if none exists for [projectId].
  /// Preserves all fields of existing rows — uses InsertMode.insertOrIgnore.
  /// Use this to satisfy FK constraints without clobbering user-set state.
  Future<void> insertProjectIfMissing({required String projectId}) async {
    await into(projectsTable).insert(
      ProjectsTableCompanion.insert(projectId: projectId),
      mode: InsertMode.insertOrIgnore,
    );
  }
}
