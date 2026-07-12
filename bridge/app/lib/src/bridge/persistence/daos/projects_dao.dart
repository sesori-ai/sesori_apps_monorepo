import "package:drift/drift.dart";

import "../database.dart";
import "../tables/projects_table.dart";

part "projects_dao.g.dart";

@DriftAccessor(tables: [ProjectsTable])
class ProjectsDao extends DatabaseAccessor<AppDatabase> with _$ProjectsDaoMixin {
  ProjectsDao(super.attachedDatabase);

  // `path` is the project's live directory; `projectId` is its stable
  // identifier (for every shipped plugin: the directory the project was FIRST
  // opened at). They diverge when a folder is moved on disk and re-opened —
  // [recordOpenedProject] is the only writer that stores a meaningful path.
  // Every other insert below stamps the project id as the row's `path` purely
  // as the new-row default (correct until a move is recorded); none of their
  // conflict clauses touch `path`, so an existing recorded path is preserved.

  /// Returns every stored project row.
  Future<List<ProjectDto>> getAllProjects() async {
    return select(projectsTable).get();
  }

  /// Returns the stored row for [projectId], or null when none exists.
  Future<ProjectDto?> getProject({required String projectId}) async {
    return (select(projectsTable)..where((t) => t.projectId.equals(projectId))).getSingleOrNull();
  }

  /// The live directory stored for [projectId], or null when the bridge has no
  /// recorded project with that id. `path` is non-nullable in the schema, so a
  /// present row is authoritative — never infer a directory from the id.
  Future<String?> getResolvedPath({required String projectId}) async {
    final row = await getProject(projectId: projectId);
    return row?.path;
  }

  /// Records [projectId] as an explicitly-opened folder by storing [path] and
  /// the exact timestamps, creating the row if missing. On conflict only
  /// [path], [createdAt] and [updatedAt] are replaced with the supplied values,
  /// preserving other user-set fields. Lets a folder with no sessions yet
  /// survive a refresh and refreshes the stored path when a moved folder is
  /// re-opened.
  Future<void> recordOpenedProject({
    required String projectId,
    required String path,
    required int createdAt,
    required int updatedAt,
  }) async {
    await into(projectsTable).insert(
      ProjectsTableCompanion.insert(
        projectId: projectId,
        path: path,
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
      ),
      onConflict: DoUpdate(
        (old) => ProjectsTableCompanion(
          path: Value(path),
          createdAt: Value(createdAt),
          updatedAt: Value(updatedAt),
        ),
        target: [projectsTable.projectId],
      ),
    );
  }

  /// Sets the bridge-persisted display-name override for [projectId], creating
  /// the row if missing. Updates only displayName on conflict, preserving all
  /// other fields. Used to persist a rename for a bridge-derived plugin that
  /// has no backend to store the name.
  Future<void> setDisplayName({required String projectId, required String displayName}) async {
    await into(projectsTable).insert(
      ProjectsTableCompanion.insert(
        projectId: projectId,
        path: projectId,
        displayName: Value(displayName),
      ),
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
      ProjectsTableCompanion.insert(
        projectId: projectId,
        path: projectId,
        hidden: const Value(true),
      ),
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
      ProjectsTableCompanion.insert(
        projectId: projectId,
        path: projectId,
        hidden: const Value(false),
      ),
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

  /// Inserts a minimal project row if none exists for each id in [projectIds].
  /// Preserves all fields of existing rows — uses InsertMode.insertOrIgnore.
  /// Use this to satisfy FK constraints without clobbering user-set state.
  Future<void> insertProjectsIfMissing({required List<String> projectIds}) async {
    if (projectIds.isEmpty) return;
    await batch((b) {
      b.insertAll(
        projectsTable,
        projectIds
            .map(
              (id) => ProjectsTableCompanion.insert(projectId: id, path: id),
            )
            .toList(),
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  /// Inserts project rows with the exact [activities] for ids that are missing.
  /// Existing rows are untouched.
  Future<void> insertMissingProjectsWithActivity({
    required Map<String, ({int createdAt, int updatedAt})> activities,
  }) async {
    if (activities.isEmpty) return;
    await batch((b) {
      b.insertAll(
        projectsTable,
        activities.entries.map((e) {
          return ProjectsTableCompanion.insert(
            projectId: e.key,
            path: e.key,
            createdAt: Value(e.value.createdAt),
            updatedAt: Value(e.value.updatedAt),
          );
        }).toList(),
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  Future<void> setActivity({required String projectId, required int createdAt, required int updatedAt}) async {
    await into(projectsTable).insert(
      ProjectsTableCompanion.insert(
        projectId: projectId,
        path: projectId,
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
      ),
      onConflict: DoUpdate(
        (old) => ProjectsTableCompanion(
          createdAt: Value(createdAt),
          updatedAt: Value(updatedAt),
        ),
        target: [projectsTable.projectId],
      ),
    );
  }

  /// Replaces the activity for every entry in [activities] in a single
  /// transaction. Rows are created if missing; existing rows are overwritten.
  Future<void> setAllActivities({required Map<String, ({int createdAt, int updatedAt})> activities}) async {
    if (activities.isEmpty) return;
    await transaction(() async {
      for (final entry in activities.entries) {
        await setActivity(
          projectId: entry.key,
          createdAt: entry.value.createdAt,
          updatedAt: entry.value.updatedAt,
        );
      }
    });
  }
}
