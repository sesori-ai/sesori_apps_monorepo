import "package:drift/drift.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../database.dart";
import "../tables/session_options_cache_table.dart";

part "session_options_cache_dao.g.dart";

@DriftAccessor(tables: [SessionOptionsCacheTable])
class SessionOptionsCacheDao extends DatabaseAccessor<AppDatabase> with _$SessionOptionsCacheDaoMixin {
  SessionOptionsCacheDao(super.attachedDatabase);

  Future<SessionOptionsCacheDto?> getRow({
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

  Future<bool> compareAndSet({
    required SessionOptionsCacheDto row,
    required int? expectedRevision,
  }) async {
    if (expectedRevision == null) {
      final inserted = await into(sessionOptionsCacheTable).insertReturningOrNull(
        row,
        onConflict: DoNothing(
          target: [sessionOptionsCacheTable.pluginId, sessionOptionsCacheTable.scope, sessionOptionsCacheTable.ownerId],
        ),
      );
      return inserted != null;
    }

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
