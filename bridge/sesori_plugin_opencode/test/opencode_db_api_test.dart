import "dart:io";

import "package:opencode_plugin/opencode_plugin.dart";
import "package:sqlite3/sqlite3.dart";
import "package:test/test.dart";

void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("opencode_db_api_test_");
    dbPath = "${tempDir.path}/test.db";
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group("getAutoVacuumMode", () {
    test("returns 0 for a new database", () async {
      final db = sqlite3.open(dbPath);
      db.execute("CREATE TABLE test (id INTEGER)");
      db.close();

      final api = OpenCodeDbApi();
      expect(await api.getAutoVacuumMode(dbPath: dbPath), 0);
    });

    test("returns 1 when auto_vacuum is FULL", () async {
      final db = sqlite3.open(dbPath);
      db.execute("PRAGMA auto_vacuum = FULL");
      db.execute("VACUUM");
      db.execute("CREATE TABLE test (id INTEGER)");
      db.close();

      final api = OpenCodeDbApi();
      expect(await api.getAutoVacuumMode(dbPath: dbPath), 1);
    });

    test("throws when database file does not exist", () async {
      final api = OpenCodeDbApi();
      // sqlite3.open on a nonexistent path creates the file,
      // but we test a truly invalid path
      await expectLater(
        () => api.getAutoVacuumMode(dbPath: "/nonexistent/dir/test.db"),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group("enableAutoVacuumAndVacuum", () {
    test("sets auto_vacuum to FULL", () async {
      final db = sqlite3.open(dbPath);
      db.execute("CREATE TABLE test (id INTEGER, data TEXT)");
      db.close();

      final api = OpenCodeDbApi();
      await api.enableAutoVacuumAndVacuum(dbPath: dbPath);
      expect(await api.getAutoVacuumMode(dbPath: dbPath), 1);
    });

    test("returns size before and after", () async {
      final db = sqlite3.open(dbPath);
      db.execute("CREATE TABLE test (id INTEGER, data TEXT)");
      // Insert data to grow the file
      for (var i = 0; i < 100; i++) {
        db.execute("INSERT INTO test VALUES ($i, '${List.filled(1000, "x").join()}')");
      }
      // Delete to create free pages
      db.execute("DELETE FROM test");
      db.close();

      final api = OpenCodeDbApi();
      final (sizeBefore, sizeAfter) = await api.enableAutoVacuumAndVacuum(
        dbPath: dbPath,
      );

      expect(sizeBefore, greaterThan(0));
      expect(sizeAfter, greaterThan(0));
      expect(sizeAfter, lessThanOrEqualTo(sizeBefore));
    });

    test("throws SqliteException when database is locked", () async {
      final db = sqlite3.open(dbPath);
      db.execute("CREATE TABLE test (id INTEGER)");
      db.execute("BEGIN EXCLUSIVE");

      final api = OpenCodeDbApi();
      await expectLater(
        () => api.enableAutoVacuumAndVacuum(dbPath: dbPath),
        throwsA(isA<SqliteException>()),
      );

      db.execute("ROLLBACK");
      db.close();
    });

    test("reclaims space from deleted rows", () async {
      final db = sqlite3.open(dbPath);
      db.execute("CREATE TABLE test (id INTEGER, data TEXT)");
      for (var i = 0; i < 500; i++) {
        db.execute("INSERT INTO test VALUES ($i, '${List.filled(500, "x").join()}')");
      }
      db.execute("DELETE FROM test");
      db.close();

      final sizeBefore = File(dbPath).lengthSync();
      final api = OpenCodeDbApi();
      final (_, sizeAfter) = await api.enableAutoVacuumAndVacuum(dbPath: dbPath);

      // After VACUUM with deleted data, file should be significantly smaller
      expect(sizeAfter, lessThan(sizeBefore));
    });
  });
}
