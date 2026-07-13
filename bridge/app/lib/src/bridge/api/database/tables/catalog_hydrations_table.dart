import "package:drift/drift.dart" hide JsonKey;
import "package:freezed_annotation/freezed_annotation.dart";

import "../../../persistence/database.dart";

part "catalog_hydrations_table.freezed.dart";

@UseRowClass(CatalogHydrationDto)
class CatalogHydrationsTable extends Table {
  TextColumn get ownerIdentity => text()();
  TextColumn get pluginId => text()();
  IntColumn get projectionVersion => integer()();
  IntColumn get completedAt => integer()();

  @override
  bool get withoutRowId => true;

  @override
  Set<Column> get primaryKey => {ownerIdentity, pluginId, projectionVersion};
}

@freezed
sealed class CatalogHydrationDto with _$CatalogHydrationDto, $CatalogHydrationsTableTableToColumns {
  const factory CatalogHydrationDto({
    required String ownerIdentity,
    required String pluginId,
    required int projectionVersion,
    required int completedAt,
  }) = _CatalogHydrationDto;

  const CatalogHydrationDto._();
}
