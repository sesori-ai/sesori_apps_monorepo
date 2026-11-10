import "package:drift/drift.dart";

import "../database.dart";
import "../tables/catalog_hydrations_table.dart";

part "catalog_hydrations_dao.g.dart";

@DriftAccessor(tables: [CatalogHydrationsTable])
class CatalogHydrationsDao(super.attachedDatabase)
    extends DatabaseAccessor<AppDatabase>
    with _$CatalogHydrationsDaoMixin {
  Future<CatalogHydrationDto?> getCompletion({
    required String pluginId,
    required int projectionVersion,
  }) {
    return (select(catalogHydrationsTable)..where(
          (table) => table.pluginId.equals(pluginId) & table.projectionVersion.equals(projectionVersion),
        ))
        .getSingleOrNull();
  }

  /// Whether any plugin has completed a hydration at [projectionVersion].
  Future<bool> hasAnyCompletion({required int projectionVersion}) async {
    final query = select(catalogHydrationsTable)
      ..where((table) => table.projectionVersion.equals(projectionVersion))
      ..limit(1);
    return await query.getSingleOrNull() != null;
  }

  Future<void> recordCompletion({required CatalogHydrationDto completion}) {
    return into(catalogHydrationsTable).insertOnConflictUpdate(completion);
  }
}
