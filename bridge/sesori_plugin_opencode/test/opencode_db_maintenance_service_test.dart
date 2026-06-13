import "dart:io";

import "package:opencode_plugin/opencode_plugin.dart";
import "package:sqlite3/sqlite3.dart";
import "package:test/test.dart";

void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("db_maintenance_test_");
    dbPath = "${tempDir.path}/opencode.db";
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group("optimizeIfNeeded", () {
    test("skips when database file does not exist", () async {
      final service = OpenCodeDbMaintenanceService(
        repository: OpenCodeDbRepository(api: OpenCodeDbApi()),
      );
      // Should not throw — repository returns null, service returns
      await service.optimizeIfNeeded(dbPath: "${tempDir.path}/missing.db");
    });

    test("skips when auto_vacuum is already FULL", () async {
      final db = sqlite3.open(dbPath);
      db.execute("PRAGMA auto_vacuum = FULL");
      db.execute("VACUUM");
      db.execute("CREATE TABLE test (id INTEGER)");
      db.close();

      final service = OpenCodeDbMaintenanceService(
        repository: OpenCodeDbRepository(api: OpenCodeDbApi()),
      );
      await service.optimizeIfNeeded(dbPath: dbPath);

      final api = OpenCodeDbApi();
      expect(await api.getAutoVacuumMode(dbPath: dbPath), 1);
    });

    test("skips when auto_vacuum is INCREMENTAL", () async {
      final db = sqlite3.open(dbPath);
      db.execute("PRAGMA auto_vacuum = INCREMENTAL");
      db.execute("VACUUM");
      db.execute("CREATE TABLE test (id INTEGER)");
      db.close();

      final service = OpenCodeDbMaintenanceService(
        repository: OpenCodeDbRepository(api: OpenCodeDbApi()),
      );
      await service.optimizeIfNeeded(dbPath: dbPath);

      final api = OpenCodeDbApi();
      expect(await api.getAutoVacuumMode(dbPath: dbPath), 2);
    });

    test("enables auto_vacuum when mode is NONE", () async {
      final db = sqlite3.open(dbPath);
      db.execute("CREATE TABLE test (id INTEGER, data TEXT)");
      for (var i = 0; i < 50; i++) {
        db.execute(
          "INSERT INTO test VALUES ($i, '${List.filled(500, "x").join()}')",
        );
      }
      db.close();

      final api = OpenCodeDbApi();
      expect(await api.getAutoVacuumMode(dbPath: dbPath), 0);

      final service = OpenCodeDbMaintenanceService(
        repository: OpenCodeDbRepository(api: api),
      );
      await service.optimizeIfNeeded(dbPath: dbPath);

      expect(await api.getAutoVacuumMode(dbPath: dbPath), 1);
    });

    test("handles locked database gracefully", () async {
      final db = sqlite3.open(dbPath);
      db.execute("CREATE TABLE test (id INTEGER)");
      db.execute("BEGIN EXCLUSIVE");

      final service = OpenCodeDbMaintenanceService(
        repository: OpenCodeDbRepository(api: OpenCodeDbApi()),
      );
      // Should not throw — repository catches SQLITE_BUSY
      await service.optimizeIfNeeded(dbPath: dbPath);

      db.execute("ROLLBACK");
      db.close();
    });

    test("handles corrupt database gracefully", () async {
      File(dbPath).writeAsBytesSync(List.filled(4096, 0xFF));

      final service = OpenCodeDbMaintenanceService(
        repository: OpenCodeDbRepository(api: OpenCodeDbApi()),
      );
      // Should not throw — repository catches error
      await service.optimizeIfNeeded(dbPath: dbPath);
    });
  });
}
