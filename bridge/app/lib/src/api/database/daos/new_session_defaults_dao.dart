import "package:drift/drift.dart";

import "../database.dart";
import "../tables/new_session_defaults_table.dart";

part "new_session_defaults_dao.g.dart";

@DriftAccessor(tables: [NewSessionDefaultsTable])
class NewSessionDefaultsDao({required AppDatabase database})
    extends DatabaseAccessor<AppDatabase>
    with _$NewSessionDefaultsDaoMixin {
  this : super(database);

  Future<NewSessionDefaultsTableData?> getRow({required String pluginId}) {
    return (select(newSessionDefaultsTable)..where((table) => table.pluginId.equals(pluginId))).getSingleOrNull();
  }

  Future<void> writeRow({required NewSessionDefaultsTableData row}) async {
    await into(newSessionDefaultsTable).insert(
      row,
      onConflict: DoUpdate(
        (_) => NewSessionDefaultsTableCompanion(
          agent: Value(row.agent),
          agentModel: Value(row.agentModel),
        ),
        target: [newSessionDefaultsTable.pluginId],
      ),
    );
  }
}
