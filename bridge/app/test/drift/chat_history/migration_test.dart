// dart format width=80
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:sesori_bridge/src/api/database/history/chat_history_database.dart';
import 'package:test/test.dart';

import 'generated/schema.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('creates the v1 schema', () async {
    final connection = await verifier.startAt(1);
    final db = ChatHistoryDatabase(connection);

    await verifier.migrateAndValidate(db, 1);
    await db.close();
  });
}
