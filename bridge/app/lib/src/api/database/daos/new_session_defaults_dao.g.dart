// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'new_session_defaults_dao.dart';

// ignore_for_file: type=lint
mixin _$NewSessionDefaultsDaoMixin on DatabaseAccessor<AppDatabase> {
  $NewSessionDefaultsTableTable get newSessionDefaultsTable =>
      attachedDatabase.newSessionDefaultsTable;
  NewSessionDefaultsDaoManager get managers =>
      NewSessionDefaultsDaoManager(this);
}

class NewSessionDefaultsDaoManager {
  final _$NewSessionDefaultsDaoMixin _db;
  NewSessionDefaultsDaoManager(this._db);
  $$NewSessionDefaultsTableTableTableManager get newSessionDefaultsTable =>
      $$NewSessionDefaultsTableTableTableManager(
        _db.attachedDatabase,
        _db.newSessionDefaultsTable,
      );
}
