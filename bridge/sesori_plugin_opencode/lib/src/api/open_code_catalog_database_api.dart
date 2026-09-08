import "package:sqlite3/sqlite3.dart";

class const OpenCodeCatalogDatabaseException({required final String message, required final Object? cause})
    implements Exception {
  @override
  String toString() => "OpenCodeCatalogDatabaseException: $message${cause == null ? "" : ": $cause"}";
}

typedef OpenCodeReadOnlyDatabaseOpener = Database Function({required String path});

Database _openReadOnly({required String path}) => sqlite3.open(path, mode: OpenMode.readOnly);

class const OpenCodeCatalogProjectRow({
  required final String id,
  required final String worktree,
  required final String? name,
  required final int createdAt,
  required final int updatedAt,
  required final List<String> sandboxes,
});

class const OpenCodeCatalogProjectDirectoryRow({
  required final String projectId,
  required final String directory,
  required final String? type,
  required final int createdAt,
});

class const OpenCodeCatalogSessionRow({
  required final String id,
  required final String projectId,
  required final String? parentId,
  required final String directory,
  required final String title,
  required final int createdAt,
  required final int updatedAt,
  required final int? archivedAt,
});

class const OpenCodeCatalogDatabaseSnapshot({
  required final List<OpenCodeCatalogProjectRow> projects,
  required final List<OpenCodeCatalogProjectDirectoryRow> projectDirectories,
  required final List<OpenCodeCatalogSessionRow> sessions,
});

/// Layer-1 read-only wrapper around OpenCode's SQLite catalog.
class OpenCodeCatalogDatabaseApi({required final OpenCodeReadOnlyDatabaseOpener _opener}) {
  static OpenCodeCatalogDatabaseApi production() {
    return OpenCodeCatalogDatabaseApi(opener: _openReadOnly);
  }

  OpenCodeCatalogDatabaseSnapshot read({required String databasePath}) {
    Database? database;
    try {
      database = _opener(path: databasePath);
      database.execute("BEGIN");
      _validateSchema(database: database);
      _validateSandboxJson(database: database);

      final sandboxesByProject = <String, List<String>>{};
      for (final row in database.select(
        "SELECT p.id AS project_id, j.value AS sandbox "
        "FROM project AS p JOIN json_each(p.sandboxes) AS j ORDER BY p.id, j.key",
      )) {
        final projectId = _requiredText(value: row["project_id"], field: "project.id");
        final sandbox = _requiredText(value: row["sandbox"], field: "project.sandboxes[]");
        sandboxesByProject.putIfAbsent(projectId, () => <String>[]).add(sandbox);
      }

      final projects = [
        for (final row in database.select(
          "SELECT id, worktree, name, time_created, time_updated FROM project ORDER BY id",
        ))
          OpenCodeCatalogProjectRow(
            id: _requiredText(value: row["id"], field: "project.id"),
            worktree: _requiredText(value: row["worktree"], field: "project.worktree"),
            name: _optionalText(value: row["name"], field: "project.name"),
            createdAt: _requiredInt(value: row["time_created"], field: "project.time_created"),
            updatedAt: _requiredInt(value: row["time_updated"], field: "project.time_updated"),
            sandboxes: List<String>.unmodifiable(
              sandboxesByProject[_requiredText(value: row["id"], field: "project.id")] ?? const [],
            ),
          ),
      ];
      final projectDirectories = [
        for (final row in database.select(
          "SELECT project_id, directory, type, time_created FROM project_directory "
          "ORDER BY project_id, directory",
        ))
          OpenCodeCatalogProjectDirectoryRow(
            projectId: _requiredText(value: row["project_id"], field: "project_directory.project_id"),
            directory: _requiredText(value: row["directory"], field: "project_directory.directory"),
            type: _optionalText(value: row["type"], field: "project_directory.type"),
            createdAt: _requiredInt(value: row["time_created"], field: "project_directory.time_created"),
          ),
      ];
      final sessions = [
        for (final row in database.select(
          "SELECT id, project_id, parent_id, directory, title, time_created, time_updated, time_archived "
          "FROM session ORDER BY id",
        ))
          OpenCodeCatalogSessionRow(
            id: _requiredText(value: row["id"], field: "session.id"),
            projectId: _requiredText(value: row["project_id"], field: "session.project_id"),
            parentId: _optionalText(value: row["parent_id"], field: "session.parent_id"),
            directory: _requiredText(value: row["directory"], field: "session.directory"),
            title: _requiredText(value: row["title"], field: "session.title"),
            createdAt: _requiredInt(value: row["time_created"], field: "session.time_created"),
            updatedAt: _requiredInt(value: row["time_updated"], field: "session.time_updated"),
            archivedAt: _optionalInt(value: row["time_archived"], field: "session.time_archived"),
          ),
      ];
      database.execute("COMMIT");
      return OpenCodeCatalogDatabaseSnapshot(
        projects: List.unmodifiable(projects),
        projectDirectories: List.unmodifiable(projectDirectories),
        sessions: List.unmodifiable(sessions),
      );
    } on OpenCodeCatalogDatabaseException {
      rethrow;
    } on Object catch (error) {
      throw OpenCodeCatalogDatabaseException(message: "OpenCode catalog snapshot read failed", cause: error);
    } finally {
      // Closing a failed read transaction rolls it back without issuing any
      // write-affecting recovery command against OpenCode's database.
      database?.close();
    }
  }

  void _validateSchema({required Database database}) {
    const requiredText = (type: "TEXT", required: true);
    const optionalText = (type: "TEXT", required: false);
    const requiredInteger = (type: "INTEGER", required: true);
    const optionalInteger = (type: "INTEGER", required: false);
    const expected = <String, Map<String, ({String type, bool required})>>{
      "project": {
        "id": requiredText,
        "worktree": requiredText,
        "name": optionalText,
        "time_created": requiredInteger,
        "time_updated": requiredInteger,
        "sandboxes": requiredText,
      },
      "project_directory": {
        "project_id": requiredText,
        "directory": requiredText,
        "type": optionalText,
        "time_created": requiredInteger,
      },
      "session": {
        "id": requiredText,
        "project_id": requiredText,
        "parent_id": optionalText,
        "directory": requiredText,
        "title": requiredText,
        "time_created": requiredInteger,
        "time_updated": requiredInteger,
        "time_archived": optionalInteger,
      },
    };
    for (final table in expected.entries) {
      final rows = database.select('SELECT name, type, "notnull", pk FROM pragma_table_info(?)', [table.key]);
      if (rows.isEmpty) {
        throw OpenCodeCatalogDatabaseException(message: "Missing OpenCode ${table.key} table", cause: null);
      }
      final actual = <String, ({String type, bool required})>{
        for (final row in rows)
          _requiredText(value: row["name"], field: "schema column"): (
            type: _requiredText(value: row["type"], field: "schema type").toUpperCase(),
            required:
                _requiredInt(value: row["notnull"], field: "schema notnull") == 1 ||
                _requiredInt(value: row["pk"], field: "schema primary key") > 0,
          ),
      };
      for (final column in table.value.entries) {
        final definition = actual[column.key];
        if (definition == null ||
            definition.type != column.value.type ||
            (column.value.required && !definition.required)) {
          throw OpenCodeCatalogDatabaseException(
            message: "Incompatible OpenCode ${table.key}.${column.key} column",
            cause: null,
          );
        }
      }
    }
  }

  void _validateSandboxJson({required Database database}) {
    final malformed = database.select(
      "SELECT id FROM project WHERE typeof(sandboxes) <> 'text' OR json_valid(sandboxes) = 0 "
      "OR json_type(sandboxes) <> 'array' "
      "OR EXISTS (SELECT 1 FROM json_each(project.sandboxes) WHERE type <> 'text') LIMIT 1",
    );
    if (malformed.isNotEmpty) {
      throw const OpenCodeCatalogDatabaseException(message: "Malformed OpenCode project sandboxes", cause: null);
    }
  }

  String _requiredText({required Object? value, required String field}) {
    if (value is! String || value.trim().isEmpty) {
      throw OpenCodeCatalogDatabaseException(message: "Invalid $field", cause: null);
    }
    return value;
  }

  String? _optionalText({required Object? value, required String field}) {
    if (value == null) return null;
    if (value is! String) throw OpenCodeCatalogDatabaseException(message: "Invalid $field", cause: null);
    return value.trim().isEmpty ? null : value;
  }

  int _requiredInt({required Object? value, required String field}) {
    if (value is! int) throw OpenCodeCatalogDatabaseException(message: "Invalid $field", cause: null);
    return value;
  }

  int? _optionalInt({required Object? value, required String field}) {
    if (value == null) return null;
    if (value is! int) throw OpenCodeCatalogDatabaseException(message: "Invalid $field", cause: null);
    return value;
  }
}
