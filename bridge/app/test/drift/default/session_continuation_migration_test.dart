import "package:drift_dev/api/migrations_native.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:test/test.dart";

import "generated/schema.dart";

void main() {
  test("v17 to v18 creates empty continuation storage without backfilling sessions", () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.startAt(17);
    final database = AppDatabase(connection);
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 18);
    expect(await database.customSelect("SELECT * FROM session_continuations").get(), isEmpty);
    final foreignKeys = await database.customSelect("PRAGMA foreign_key_list('session_continuations')").get();
    expect(foreignKeys.single.read<String>("table"), "sessions_table");
    expect(foreignKeys.single.read<String>("on_delete"), "CASCADE");
  });
}
