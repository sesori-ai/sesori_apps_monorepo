import "dart:async";
import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_bridge/src/api/database/daos/session_options_cache_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "../../helpers/test_database.dart";

void main() {
  test("current schema creates the session options cache with its project cascade", () async {
    final database = createTestDatabase();
    addTearDown(database.close);

    final definition = await database
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'session_options_cache_table'",
        )
        .getSingle();
    expect(database.schemaVersion, 12);
    expect(definition.read<String>("sql").toUpperCase(), contains("WITHOUT ROWID"));

    final foreignKeys = await database.customSelect("PRAGMA foreign_key_list('session_options_cache_table')").get();
    expect(foreignKeys, hasLength(1));
    expect(foreignKeys.single.read<String>("table"), "projects_table");
    expect(foreignKeys.single.read<String>("from"), "project_id");
    expect(foreignKeys.single.read<String>("to"), "project_id");
    expect(foreignKeys.single.read<String>("on_delete").toUpperCase(), "CASCADE");
  });

  test("session options CAS requires the exact next revision", () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final dao = SessionOptionsCacheDao(database);
    const row = SessionOptionsCacheTableData(
      pluginId: "plugin",
      scope: PluginSessionOptionsScope.plugin,
      ownerId: "plugin",
      projectId: null,
      capturedProjectPath: null,
      revision: 1,
      capturedAt: 1,
      completeness: PluginSessionOptionsCompleteness.complete,
      agentsJson: "{}",
      providersJson: "{}",
      commandsJson: "{}",
    );

    expect(await dao.compareAndSet(row: row.copyWith(revision: 0), expectedRevision: null), isFalse);
    expect(await dao.compareAndSet(row: row, expectedRevision: null), isTrue);
    expect(await dao.compareAndSet(row: row, expectedRevision: 1), isFalse);
    expect(await dao.compareAndSet(row: row.copyWith(revision: 3), expectedRevision: 1), isFalse);
    expect(await dao.compareAndSet(row: row.copyWith(revision: 2), expectedRevision: 1), isTrue);
  });

  test("file-backed readers observe the committed snapshot during a writer transaction", () async {
    final directory = await Directory.systemTemp.createTemp("sesori-database-test-");
    final database = AppDatabase.openFile(file: File(p.join(directory.path, "catalog.sqlite")));
    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });
    await database.projectsDao.recordOpenedProject(
      projectId: "project",
      path: "/projects/project",
      displayName: null,
      createdAt: 1,
      updatedAt: 1,
    );
    expect(
      (await database.customSelect("PRAGMA journal_mode").getSingle()).read<String>("journal_mode"),
      "wal",
    );

    final transactionStarted = Completer<void>();
    final releaseTransaction = Completer<void>();
    final write = database.transaction(() async {
      await database.projectsDao.setActivity(projectId: "project", createdAt: 1, updatedAt: 2);
      transactionStarted.complete();
      await releaseTransaction.future;
    });
    await transactionStarted.future;

    final rows = await database.projectsDao.getCatalogProjects().timeout(const Duration(seconds: 1));
    expect(rows.single.updatedAt, 1);

    releaseTransaction.complete();
    await write;
    expect((await database.projectsDao.getCatalogProjects()).single.updatedAt, 2);
  });
}
