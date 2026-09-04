import "package:drift/drift.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../database.dart";
import "../tables/session_options_cache_table.dart";

part "session_options_cache_dao.g.dart";

@DriftAccessor(tables: [SessionOptionsCacheTable])
class SessionOptionsCacheDao({required AppDatabase database}) extends DatabaseAccessor<AppDatabase> with _$SessionOptionsCacheDaoMixin {
  this : super(database);

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

  /// Project identifiers this plugin currently holds a project-scoped snapshot
  /// for. A plugin-scoped plugin has no such rows and yields nothing.
  ///
  /// Projects to the id column alone: the caller refreshes each project by id
  /// and never reads the row, so selecting whole rows would decode every cached
  /// catalog payload for nothing.
  Future<List<String>> getCachedProjectIds({required String pluginId}) async {
    final query = selectOnly(sessionOptionsCacheTable)
      ..addColumns([sessionOptionsCacheTable.projectId])
      ..where(
        sessionOptionsCacheTable.pluginId.equals(pluginId) &
            sessionOptionsCacheTable.scope.equalsValue(PluginSessionOptionsScope.project) &
            sessionOptionsCacheTable.projectId.isNotNull(),
      );
    final rows = await query.get();
    return [for (final row in rows) ?row.read(sessionOptionsCacheTable.projectId)];
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
