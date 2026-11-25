// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_options_cache_dao.dart';

// ignore_for_file: type=lint
mixin _$SessionOptionsCacheDaoMixin on DatabaseAccessor<AppDatabase> {
  $SessionOptionsCacheTableTable get sessionOptionsCacheTable =>
      attachedDatabase.sessionOptionsCacheTable;
  SessionOptionsCacheDaoManager get managers =>
      SessionOptionsCacheDaoManager(this);
}

class SessionOptionsCacheDaoManager {
  final _$SessionOptionsCacheDaoMixin _db;
  SessionOptionsCacheDaoManager(this._db);
  $$SessionOptionsCacheTableTableTableManager get sessionOptionsCacheTable =>
      $$SessionOptionsCacheTableTableTableManager(
        _db.attachedDatabase,
        _db.sessionOptionsCacheTable,
      );
}
