import "dart:io";

import "package:opencode_plugin/src/api/open_code_catalog_database_api.dart";
import "package:opencode_plugin/src/message_part_mapper.dart";
import "package:opencode_plugin/src/plugin_model_mapper.dart";
import "package:opencode_plugin/src/repositories/open_code_catalog_repository.dart";
import "package:opencode_plugin/src/runtime/open_code_plugin_descriptor.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show maxTranscriptImageCollectionBytes;
import "package:sqlite3/sqlite3.dart";
import "package:test/test.dart";

void main() {
  group("OpenCodeCatalogRepository", () {
    late Directory temporaryDirectory;
    late String databasePath;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp("opencode-catalog-");
      databasePath = "${temporaryDirectory.path}/catalog.db";
    });

    tearDown(() async {
      await temporaryDirectory.delete(recursive: true);
    });

    test("reads every root and descendant without transcript tables or pagination", () async {
      final database = sqlite3.open(databasePath);
      _createSchema(database: database);
      _insertProject(database: database, id: "real", worktree: "${temporaryDirectory.path}/repo");
      for (var index = 0; index < 125; index++) {
        _insertSession(
          database: database,
          id: "root-$index",
          projectId: "real",
          directory: "${temporaryDirectory.path}/repo/package-$index",
          parentId: null,
        );
        _insertSession(
          database: database,
          id: "child-$index",
          projectId: "real",
          directory: "${temporaryDirectory.path}/repo/package-$index",
          parentId: "root-$index",
        );
      }
      database.close();

      final result = await _repository().read(
        environment: {"OPENCODE_DB": databasePath, "HOME": temporaryDirectory.path},
        cancellation: const _NeverCancelled(),
      );

      final snapshot = (result as PluginCatalogSnapshotAvailable).snapshot;
      expect(snapshot.projects, hasLength(1));
      expect(snapshot.projects.single.sessions, hasLength(250));
      final child = snapshot.projects.single.sessions.singleWhere((session) => session.id == "child-124");
      expect(child.parentID, "root-124");
      expect(child.projectID, "${temporaryDirectory.path}/repo");
    });

    test("maps sandbox, project-directory, nested, and uncovered global families", () async {
      final database = sqlite3.open(databasePath);
      _createSchema(database: database);
      _insertProject(
        database: database,
        id: "real",
        worktree: "${temporaryDirectory.path}/repo",
        sandboxes: '["${temporaryDirectory.path}/sandbox"]',
      );
      database.execute(
        "INSERT INTO project_directory(project_id,directory,type,time_created) VALUES(?,?,?,?)",
        ["real", "${temporaryDirectory.path}/worktree", "git_worktree", 1],
      );
      database.execute(
        "INSERT INTO project_directory(project_id,directory,type,time_created) VALUES(?,?,?,?)",
        ["real", "${temporaryDirectory.path}/legacy-directory", null, 1],
      );
      _insertProject(database: database, id: "global", worktree: "/");
      _insertSession(
        database: database,
        id: "nested",
        projectId: "global",
        directory: "${temporaryDirectory.path}/repo/pkg",
        parentId: null,
      );
      _insertSession(
        database: database,
        id: "sandbox",
        projectId: "real",
        directory: "${temporaryDirectory.path}/sandbox/subdir",
        parentId: null,
      );
      _insertSession(
        database: database,
        id: "worktree",
        projectId: "real",
        directory: "${temporaryDirectory.path}/worktree/subdir",
        parentId: null,
      );
      _insertSession(
        database: database,
        id: "nullable-directory-type",
        projectId: "real",
        directory: "${temporaryDirectory.path}/legacy-directory/subdir",
        parentId: null,
      );
      _insertSession(
        database: database,
        id: "global-root",
        projectId: "global",
        directory: "${temporaryDirectory.path}/standalone",
        parentId: null,
      );
      database.close();

      final result = await _repository().read(
        environment: {"OPENCODE_DB": databasePath, "HOME": temporaryDirectory.path},
        cancellation: const _NeverCancelled(),
      );

      final projects = (result as PluginCatalogSnapshotAvailable).snapshot.projects;
      final real = projects.singleWhere((family) => family.project.id == "${temporaryDirectory.path}/repo");
      expect(
        real.sessions.map((session) => session.id),
        unorderedEquals(["nested", "sandbox", "worktree", "nullable-directory-type"]),
      );
      expect(
        projects.singleWhere((family) => family.project.directory == "${temporaryDirectory.path}/standalone").sessions,
        hasLength(1),
      );
    });

    test("retains archived-only global families with descendants and timestamps", () async {
      final database = sqlite3.open(databasePath);
      _createSchema(database: database);
      _insertProject(database: database, id: "global", worktree: "/");
      database.execute(
        "INSERT INTO session(id,project_id,parent_id,directory,title,time_created,time_updated,time_archived) "
        "VALUES(?,?,?,?,?,?,?,?)",
        ["archived-root", "global", null, "${temporaryDirectory.path}/archived", "Archived root", 10, 20, 30],
      );
      database.execute(
        "INSERT INTO session(id,project_id,parent_id,directory,title,time_created,time_updated,time_archived) "
        "VALUES(?,?,?,?,?,?,?,?)",
        [
          "archived-child",
          "global",
          "archived-root",
          "${temporaryDirectory.path}/archived",
          "Archived child",
          11,
          21,
          31,
        ],
      );
      database.close();

      final result = await _repository().read(
        environment: {"OPENCODE_DB": databasePath, "HOME": temporaryDirectory.path},
        cancellation: const _NeverCancelled(),
      );

      final projects = (result as PluginCatalogSnapshotAvailable).snapshot.projects;
      final family = projects.singleWhere(
        (entry) => entry.project.directory == "${temporaryDirectory.path}/archived",
      );
      expect(family.sessions.map((session) => session.id), unorderedEquals(["archived-root", "archived-child"]));
      expect(family.sessions.singleWhere((session) => session.id == "archived-root").time?.archived, 30);
      expect(family.sessions.singleWhere((session) => session.id == "archived-child").time?.archived, 31);
    });

    test("ordinary read-only connection sees committed WAL and leaves database and WAL bytes unchanged", () async {
      final writer = sqlite3.open(databasePath);
      writer.execute("PRAGMA journal_mode=WAL");
      writer.execute("PRAGMA wal_autocheckpoint=0");
      _createSchema(database: writer);
      _insertProject(database: writer, id: "real", worktree: "${temporaryDirectory.path}/repo");
      _insertSession(
        database: writer,
        id: "wal-root",
        projectId: "real",
        directory: "${temporaryDirectory.path}/repo",
        parentId: null,
      );
      final walPath = "$databasePath-wal";
      final mainBefore = File(databasePath).readAsBytesSync();
      final walBefore = File(walPath).readAsBytesSync();

      final result = await _repository().read(
        environment: {"OPENCODE_DB": databasePath, "HOME": temporaryDirectory.path},
        cancellation: const _NeverCancelled(),
      );

      expect((result as PluginCatalogSnapshotAvailable).snapshot.projects.single.sessions.single.id, "wal-root");
      expect(File(databasePath).readAsBytesSync(), mainBefore);
      expect(File(walPath).readAsBytesSync(), walBefore);
      writer.close();
    });

    test("fails closed for malformed schema, JSON, type, and ancestry", () async {
      Future<void> expectFailure(void Function(Database database) mutate) async {
        final file = File(databasePath);
        if (file.existsSync()) file.deleteSync();
        final database = sqlite3.open(databasePath);
        _createSchema(database: database);
        _insertProject(database: database, id: "real", worktree: "${temporaryDirectory.path}/repo");
        mutate(database);
        database.close();
        await expectLater(
          _repository().read(
            environment: {"OPENCODE_DB": databasePath, "HOME": temporaryDirectory.path},
            cancellation: const _NeverCancelled(),
          ),
          throwsA(isA<OpenCodeCatalogDatabaseException>()),
        );
      }

      await expectFailure((database) => database.execute("DROP TABLE project_directory"));
      await expectFailure(
        (database) => database.execute("UPDATE project SET sandboxes='not-json' WHERE id='real'"),
      );
      await expectFailure(
        (database) => database.execute(
          "INSERT INTO project_directory(project_id,directory,type,time_created) VALUES(?,?,?,?)",
          ["real", "${temporaryDirectory.path}/repo", "future_type", 1],
        ),
      );
      await expectFailure((database) {
        _insertSession(
          database: database,
          id: "orphan",
          projectId: "real",
          directory: "${temporaryDirectory.path}/repo",
          parentId: "missing",
        );
      });
    });

    test("Windows database paths map forward slashes to native separators", () async {
      final databaseApi = _FakeCatalogDatabaseApi(
        snapshot: const OpenCodeCatalogDatabaseSnapshot(
          projects: [
            OpenCodeCatalogProjectRow(
              id: "real",
              worktree: "C:/repo",
              name: null,
              createdAt: 1,
              updatedAt: 2,
              sandboxes: ["C:/repo-sandbox"],
            ),
          ],
          projectDirectories: [],
          sessions: [],
        ),
      );
      final repository = OpenCodeCatalogRepository(
        databaseApi: databaseApi,
        modelMapper: const PluginModelMapper(
          messagePartMapper: MessagePartMapper(),
          maxTranscriptAttachmentBytes: maxTranscriptImageCollectionBytes,
        ),
        operatingSystem: PlatformOs.windows,
        fileExists: ({required path}) => true,
        trustedInstallationChannel: null,
      );

      final result = await repository.read(
        environment: const {"OPENCODE_DB": "C:/data/opencode.db"},
        cancellation: const _NeverCancelled(),
      );

      expect(databaseApi.path, "C:/data/opencode.db");
      expect((result as PluginCatalogSnapshotAvailable).snapshot.projects.single.project.directory, r"C:\repo");
    });

    test("production descriptor reads ordinary public-channel default database", () async {
      final defaultDirectory = Directory("${temporaryDirectory.path}/.local/share/opencode")
        ..createSync(recursive: true);
      final defaultPath = "${defaultDirectory.path}/opencode.db";
      final database = sqlite3.open(defaultPath);
      _createSchema(database: database);
      _insertProject(database: database, id: "real", worktree: "${temporaryDirectory.path}/repo");
      database.close();

      final result = await const OpenCodePluginDescriptor().readCatalogSnapshot(
        config: const PluginConfig(values: {"no-auto-start": false, "bin": null}),
        environment: {"HOME": temporaryDirectory.path},
        cancellation: const _NeverCancelled(),
      );

      expect(result, isA<PluginCatalogSnapshotAvailable>());
    });

    test("attach mode always keeps the existing server import path", () async {
      final result = await const OpenCodePluginDescriptor().readCatalogSnapshot(
        config: const PluginConfig(values: {"no-auto-start": true, "port": 4096}),
        environment: {"OPENCODE_DB": databasePath, "HOME": temporaryDirectory.path},
        cancellation: const _NeverCancelled(),
      );

      expect(result, isA<PluginCatalogSnapshotUnavailable>());
      expect(File(databasePath).existsSync(), isFalse);
    });

    test("missing and unidentifiable database choices remain unavailable", () async {
      expect(
        await _repository().read(
          environment: {"OPENCODE_DB": ":memory:", "HOME": temporaryDirectory.path},
          cancellation: const _NeverCancelled(),
        ),
        isA<PluginCatalogSnapshotUnavailable>(),
      );
      expect(
        await _repository().read(
          environment: {"OPENCODE_DB": "missing.db", "HOME": temporaryDirectory.path},
          cancellation: const _NeverCancelled(),
        ),
        isA<PluginCatalogSnapshotUnavailable>(),
      );

      final defaultDirectory = Directory("${temporaryDirectory.path}/.local/share/opencode")
        ..createSync(recursive: true);
      File("${defaultDirectory.path}/opencode.db").writeAsBytesSync(const [0]);
      expect(
        await _repository().read(
          environment: {"HOME": temporaryDirectory.path},
          cancellation: const _NeverCancelled(),
        ),
        isA<PluginCatalogSnapshotUnavailable>(),
        reason: "unknown/custom binary channel must not silently select opencode.db",
      );
    });
  });
}

OpenCodeCatalogRepository _repository() {
  return OpenCodeCatalogRepository(
    databaseApi: OpenCodeCatalogDatabaseApi.production(),
    modelMapper: const PluginModelMapper(
      messagePartMapper: MessagePartMapper(),
      maxTranscriptAttachmentBytes: maxTranscriptImageCollectionBytes,
    ),
    operatingSystem: PlatformOs.macos,
    fileExists: openCodeCatalogFileExists,
    trustedInstallationChannel: null,
  );
}

void _createSchema({required Database database}) {
  database.execute("""
    CREATE TABLE project(
      id TEXT PRIMARY KEY,
      worktree TEXT NOT NULL,
      name TEXT,
      time_created INTEGER NOT NULL,
      time_updated INTEGER NOT NULL,
      sandboxes TEXT NOT NULL
    );
    CREATE TABLE project_directory(
      project_id TEXT NOT NULL,
      directory TEXT NOT NULL,
      type TEXT,
      time_created INTEGER NOT NULL
    );
    CREATE TABLE session(
      id TEXT PRIMARY KEY,
      project_id TEXT NOT NULL,
      parent_id TEXT,
      directory TEXT NOT NULL,
      title TEXT NOT NULL,
      time_created INTEGER NOT NULL,
      time_updated INTEGER NOT NULL,
      time_archived INTEGER
    );
  """);
}

void _insertProject({
  required Database database,
  required String id,
  required String worktree,
  String sandboxes = "[]",
}) {
  database.execute(
    "INSERT INTO project(id,worktree,name,time_created,time_updated,sandboxes) VALUES(?,?,?,?,?,?)",
    [id, worktree, null, 1, 2, sandboxes],
  );
}

void _insertSession({
  required Database database,
  required String id,
  required String projectId,
  required String directory,
  required String? parentId,
}) {
  database.execute(
    "INSERT INTO session(id,project_id,parent_id,directory,title,time_created,time_updated,time_archived) "
    "VALUES(?,?,?,?,?,?,?,?)",
    [id, projectId, parentId, directory, "Session $id", 10, 20, null],
  );
}

class _FakeCatalogDatabaseApi({required final OpenCodeCatalogDatabaseSnapshot snapshot})
    implements OpenCodeCatalogDatabaseApi {
  String? path;

  @override
  OpenCodeCatalogDatabaseSnapshot read({required String databasePath}) {
    path = databasePath;
    return snapshot;
  }
}

class const _NeverCancelled() implements PluginCatalogCancellationSignal {
  @override
  bool get isCancelled => false;
}
