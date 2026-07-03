import "package:drift/drift.dart";

import "../database.dart";
import "../tables/projects_table.dart";

part "projects_dao.g.dart";

@DriftAccessor(tables: [ProjectsTable])
class ProjectsDao extends DatabaseAccessor<AppDatabase> with _$ProjectsDaoMixin {
  ProjectsDao(super.attachedDatabase);

  // Every insert below stamps the project id as the row's `path`: the id has
  // always been the project's directory path for every shipped plugin. If ids
  // ever stop being paths, insert sites must take an explicit path instead.

  /// Returns every stored project row. Used by the bridge-derived project path
  /// to read paths, display-name overrides, and opened-folder timestamps.
  Future<List<ProjectDto>> getAllProjects() async {
    return select(projectsTable).get();
  }

  /// Records [projectId] as an explicitly-opened folder by stamping [openedAt],
  /// creating the row if missing. Updates only openedAt on conflict, preserving
  /// hidden/baseBranch/displayName/worktreeCounter. Lets a folder with no
  /// sessions yet resurface with a fresh time when the user re-opens it.
  Future<void> recordOpenedProject({required String projectId, required int openedAt}) async {
    await into(projectsTable).insert(
      ProjectsTableCompanion.insert(projectId: projectId, path: projectId, openedAt: Value(openedAt)),
      onConflict: DoUpdate(
        (old) => ProjectsTableCompanion(openedAt: Value(openedAt)),
        target: [projectsTable.projectId],
      ),
    );
  }

  /// Sets the bridge-persisted display-name override for [projectId], creating
  /// the row if missing. Updates only displayName on conflict. Used to persist a
  /// rename for a bridge-derived plugin that has no backend to store the name.
  Future<void> setDisplayName({required String projectId, required String displayName}) async {
    await into(projectsTable).insert(
      ProjectsTableCompanion.insert(projectId: projectId, path: projectId, displayName: Value(displayName)),
      onConflict: DoUpdate(
        (old) => ProjectsTableCompanion(displayName: Value(displayName)),
        target: [projectsTable.projectId],
      ),
    );
  }

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

  /// Marks a project as hidden. Creates the row if missing. Uses DoUpdate to
  /// update ONLY the hidden column on conflict, preserving all other fields.
  Future<void> hideProject({required String projectId}) async {
    await into(projectsTable).insert(
      ProjectsTableCompanion.insert(projectId: projectId, path: projectId, hidden: const Value(true)),
      onConflict: DoUpdate(
        (old) => const ProjectsTableCompanion(hidden: Value(true)),
        target: [projectsTable.projectId],
      ),
    );
  }

  /// Removes the hidden flag from a project. Creates the row if missing.
  /// Uses DoUpdate to update ONLY the hidden column on conflict, preserving
  /// baseBranch and worktreeCounter on existing rows.
  Future<void> unhideProject({required String projectId}) async {
    await into(projectsTable).insert(
      ProjectsTableCompanion.insert(projectId: projectId, path: projectId, hidden: const Value(false)),
      onConflict: DoUpdate(
        (old) => const ProjectsTableCompanion(hidden: Value(false)),
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
          ProjectsTableCompanion.insert(projectId: projectId, path: projectId, worktreeCounter: const Value(1)),
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
    await into(projectsTable).insert(
      ProjectsTableCompanion.insert(projectId: projectId, path: projectId, baseBranch: Value(baseBranch)),
      onConflict: DoUpdate(
        (old) => ProjectsTableCompanion(baseBranch: Value(baseBranch)),
        target: [projectsTable.projectId],
      ),
    );
  }

  /// Deletes the project row for [projectId]. The session/PR FKs cascade, so
  /// callers must first ensure nothing still references the row.
  Future<void> deleteProject({required String projectId}) async {
    await (delete(projectsTable)..where((t) => t.projectId.equals(projectId))).go();
  }

  /// Inserts a minimal project row if none exists for [projectId].
  /// Preserves all fields of existing rows — uses InsertMode.insertOrIgnore.
  /// Use this to satisfy FK constraints (and to seed a just-discovered or
  /// just-opened folder, whose openedAt stamps at insert) without clobbering
  /// user-set state.
  Future<void> insertProjectsIfMissing({required List<String> projectIds}) async {
    if (projectIds.isEmpty) return;
    await batch((b) {
      b.insertAll(
        projectsTable,
        projectIds.map((id) => ProjectsTableCompanion.insert(projectId: id, path: id)).toList(),
        mode: InsertMode.insertOrIgnore,
      );
    });
  }
}
