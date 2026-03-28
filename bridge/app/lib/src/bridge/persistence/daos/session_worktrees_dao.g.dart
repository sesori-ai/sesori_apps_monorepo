// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_worktrees_dao.dart';

// ignore_for_file: type=lint
mixin _$SessionWorktreesDaoMixin on DatabaseAccessor<AppDatabase> {
  $SessionWorktreesTableTable get sessionWorktreesTable =>
      attachedDatabase.sessionWorktreesTable;
  SessionWorktreesDaoManager get managers => SessionWorktreesDaoManager(this);
}

class SessionWorktreesDaoManager {
  final _$SessionWorktreesDaoMixin _db;
  SessionWorktreesDaoManager(this._db);
  $$SessionWorktreesTableTableTableManager get sessionWorktreesTable =>
      $$SessionWorktreesTableTableTableManager(
        _db.attachedDatabase,
        _db.sessionWorktreesTable,
      );
}
