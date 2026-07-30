import "package:drift/drift.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../database.dart";
import "../tables/session_options_cache_table.dart";

part "session_options_cache_dao.g.dart";

@DriftAccessor(tables: [SessionOptionsCacheTable])
class SessionOptionsCacheDao extends DatabaseAccessor<AppDatabase> with _$SessionOptionsCacheDaoMixin {
  SessionOptionsCacheDao(super.attachedDatabase);

  Future<SessionOptionsCacheTableData?> getRow({
    required String pluginId,
    required PluginSessionOptionsScope scope,
    required String ownerId,
  }) {
    return (select(sessionOptionsCacheTable)..where(
          (table) => table.pluginId.equals(pluginId) & table.scope.equalsValue(scope) & table.ownerId.equals(ownerId),
        ))
        .getSingleOrNull();
  }

  Future<void> deleteRow({
    required String pluginId,
    required PluginSessionOptionsScope scope,
    required String ownerId,
  }) async {
    await (delete(sessionOptionsCacheTable)..where(
          (table) => table.pluginId.equals(pluginId) & table.scope.equalsValue(scope) & table.ownerId.equals(ownerId),
        ))
        .go();
  }

  Future<bool> deleteRowIfRevision({
    required String pluginId,
    required PluginSessionOptionsScope scope,
    required String ownerId,
    required int expectedRevision,
  }) async {
    final deleted =
        await (delete(sessionOptionsCacheTable)..where(
              (table) =>
                  table.pluginId.equals(pluginId) &
                  table.scope.equalsValue(scope) &
                  table.ownerId.equals(ownerId) &
                  table.revision.equals(expectedRevision),
            ))
            .go();
    return deleted == 1;
  }

  Future<bool> compareAndSet({
    required SessionOptionsCacheTableData row,
    required int? expectedRevision,
  }) async {
    if (expectedRevision == null) {
      if (row.revision != 1) return false;
      final inserted = await into(sessionOptionsCacheTable).insertReturningOrNull(
        row,
        onConflict: DoNothing(
          target: [sessionOptionsCacheTable.pluginId, sessionOptionsCacheTable.scope, sessionOptionsCacheTable.ownerId],
        ),
      );
      return inserted != null;
    }
    if (row.revision != expectedRevision + 1) return false;

    final updated =
        await (update(sessionOptionsCacheTable)..where(
              (table) =>
                  table.pluginId.equals(row.pluginId) &
                  table.scope.equalsValue(row.scope) &
                  table.ownerId.equals(row.ownerId) &
                  table.revision.equals(expectedRevision),
            ))
            .write(row);
    return updated == 1;
  }
}
