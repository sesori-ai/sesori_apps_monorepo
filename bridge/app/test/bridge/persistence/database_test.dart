import "dart:async";
import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_bridge/src/api/database/database.dart";
import "package:test/test.dart";

void main() {
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
