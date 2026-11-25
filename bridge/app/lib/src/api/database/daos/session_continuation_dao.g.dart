// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_continuation_dao.dart';

// ignore_for_file: type=lint
mixin _$SessionContinuationDaoMixin on DatabaseAccessor<AppDatabase> {
  $ProjectsTableTable get projectsTable => attachedDatabase.projectsTable;
  $ScheduledTasksTableTable get scheduledTasksTable => attachedDatabase.scheduledTasksTable;
  $SessionTableTable get sessionTable => attachedDatabase.sessionTable;
  $SessionContinuationTableTable get sessionContinuationTable => attachedDatabase.sessionContinuationTable;
  SessionContinuationDaoManager get managers => SessionContinuationDaoManager(this);
}

class SessionContinuationDaoManager {
  final _$SessionContinuationDaoMixin _db;
  SessionContinuationDaoManager(this._db);
  $$ProjectsTableTableTableManager get projectsTable =>
      $$ProjectsTableTableTableManager(_db.attachedDatabase, _db.projectsTable);
  $$ScheduledTasksTableTableTableManager get scheduledTasksTable => $$ScheduledTasksTableTableTableManager(
    _db.attachedDatabase,
    _db.scheduledTasksTable,
  );
  $$SessionTableTableTableManager get sessionTable =>
      $$SessionTableTableTableManager(_db.attachedDatabase, _db.sessionTable);
  $$SessionContinuationTableTableTableManager get sessionContinuationTable =>
      $$SessionContinuationTableTableTableManager(
        _db.attachedDatabase,
        _db.sessionContinuationTable,
      );
}
