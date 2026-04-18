import "dart:io";

import "package:sesori_bridge/src/bridge/api/opencode_db_api.dart";
import "package:sesori_bridge/src/bridge/repositories/opencode_db_repository.dart";
import "package:sesori_bridge/src/bridge/services/opencode_db_maintenance_service.dart";
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
    test("skips when database file does not exist", () {
      final service = OpenCodeDbMaintenanceService(
        repository: OpenCodeDbRepository(api: OpenCodeDbApi()),
      );
      // Should not throw — repository returns null, service returns
      service.optimizeIfNeeded(dbPath: "${tempDir.path}/missing.db");
    });

    test("skips when auto_vacuum is already FULL", () {
      final db = sqlite3.open(dbPath);
      db.execute("PRAGMA auto_vacuum = FULL");
      db.execute("VACUUM");
      db.execute("CREATE TABLE test (id INTEGER)");
      db.close();

      final service = OpenCodeDbMaintenanceService(
        repository: OpenCodeDbRepository(api: OpenCodeDbApi()),
      );
      service.optimizeIfNeeded(dbPath: dbPath);

      final api = OpenCodeDbApi();
      expect(api.getAutoVacuumMode(dbPath: dbPath), 1);
    });

    test("skips when auto_vacuum is INCREMENTAL", () {
      final db = sqlite3.open(dbPath);
      db.execute("PRAGMA auto_vacuum = INCREMENTAL");
      db.execute("VACUUM");
      db.execute("CREATE TABLE test (id INTEGER)");
      db.close();

      final service = OpenCodeDbMaintenanceService(
        repository: OpenCodeDbRepository(api: OpenCodeDbApi()),
      );
      service.optimizeIfNeeded(dbPath: dbPath);

      final api = OpenCodeDbApi();
      expect(api.getAutoVacuumMode(dbPath: dbPath), 2);
    });

    test("enables auto_vacuum when mode is NONE", () {
      final db = sqlite3.open(dbPath);
      db.execute("CREATE TABLE test (id INTEGER, data TEXT)");
      for (var i = 0; i < 50; i++) {
        db.execute(
          "INSERT INTO test VALUES ($i, '${List.filled(500, "x").join()}')",
        );
      }
      db.close();

      final api = OpenCodeDbApi();
      expect(api.getAutoVacuumMode(dbPath: dbPath), 0);

      final service = OpenCodeDbMaintenanceService(
        repository: OpenCodeDbRepository(api: api),
      );
      service.optimizeIfNeeded(dbPath: dbPath);

      expect(api.getAutoVacuumMode(dbPath: dbPath), 1);
    });

    test("handles locked database gracefully", () {
      final db = sqlite3.open(dbPath);
      db.execute("CREATE TABLE test (id INTEGER)");
      db.execute("BEGIN EXCLUSIVE");

      final service = OpenCodeDbMaintenanceService(
        repository: OpenCodeDbRepository(api: OpenCodeDbApi()),
      );
      // Should not throw — repository catches SQLITE_BUSY
      service.optimizeIfNeeded(dbPath: dbPath);

      db.execute("ROLLBACK");
      db.close();
    });

    test("handles corrupt database gracefully", () {
      File(dbPath).writeAsBytesSync(List.filled(4096, 0xFF));

      final service = OpenCodeDbMaintenanceService(
        repository: OpenCodeDbRepository(api: OpenCodeDbApi()),
      );
      // Should not throw — repository catches error
      service.optimizeIfNeeded(dbPath: dbPath);
    });
  });
}
