// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'command_invocation_dao.dart';

// ignore_for_file: type=lint
mixin _$CommandInvocationDaoMixin on DatabaseAccessor<AppDatabase> {
  $ProjectsTableTable get projectsTable => attachedDatabase.projectsTable;
  $SessionTableTable get sessionTable => attachedDatabase.sessionTable;
  $AcceptedCommandInvocationsTableTable get acceptedCommandInvocationsTable =>
      attachedDatabase.acceptedCommandInvocationsTable;
  CommandInvocationDaoManager get managers => CommandInvocationDaoManager(this);
}

class CommandInvocationDaoManager {
  final _$CommandInvocationDaoMixin _db;
  CommandInvocationDaoManager(this._db);
  $$ProjectsTableTableTableManager get projectsTable =>
      $$ProjectsTableTableTableManager(_db.attachedDatabase, _db.projectsTable);
  $$SessionTableTableTableManager get sessionTable =>
      $$SessionTableTableTableManager(_db.attachedDatabase, _db.sessionTable);
  $$AcceptedCommandInvocationsTableTableTableManager get acceptedCommandInvocationsTable =>
      $$AcceptedCommandInvocationsTableTableTableManager(
        _db.attachedDatabase,
        _db.acceptedCommandInvocationsTable,
      );
}
