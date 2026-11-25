// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_hydrations_dao.dart';

// ignore_for_file: type=lint
mixin _$CatalogHydrationsDaoMixin on DatabaseAccessor<AppDatabase> {
  $CatalogHydrationsTableTable get catalogHydrationsTable =>
      attachedDatabase.catalogHydrationsTable;
  CatalogHydrationsDaoManager get managers => CatalogHydrationsDaoManager(this);
}

class CatalogHydrationsDaoManager {
  final _$CatalogHydrationsDaoMixin _db;
  CatalogHydrationsDaoManager(this._db);
  $$CatalogHydrationsTableTableTableManager get catalogHydrationsTable =>
      $$CatalogHydrationsTableTableTableManager(
        _db.attachedDatabase,
        _db.catalogHydrationsTable,
      );
}
