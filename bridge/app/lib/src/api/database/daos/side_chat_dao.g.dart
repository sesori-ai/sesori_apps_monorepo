// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'side_chat_dao.dart';

// ignore_for_file: type=lint
mixin _$SideChatDaoMixin on DatabaseAccessor<AppDatabase> {
  $ProjectsTableTable get projectsTable => attachedDatabase.projectsTable;
  $SessionTableTable get sessionTable => attachedDatabase.sessionTable;
  $SideChatExchangesTableTable get sideChatExchangesTable =>
      attachedDatabase.sideChatExchangesTable;
  SideChatDaoManager get managers => SideChatDaoManager(this);
}

class SideChatDaoManager {
  final _$SideChatDaoMixin _db;
  SideChatDaoManager(this._db);
  $$ProjectsTableTableTableManager get projectsTable =>
      $$ProjectsTableTableTableManager(_db.attachedDatabase, _db.projectsTable);
  $$SessionTableTableTableManager get sessionTable =>
      $$SessionTableTableTableManager(_db.attachedDatabase, _db.sessionTable);
  $$SideChatExchangesTableTableTableManager get sideChatExchangesTable =>
      $$SideChatExchangesTableTableTableManager(
        _db.attachedDatabase,
        _db.sideChatExchangesTable,
      );
}
