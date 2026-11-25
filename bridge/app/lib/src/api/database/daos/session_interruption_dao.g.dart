// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_interruption_dao.dart';

// ignore_for_file: type=lint
mixin _$SessionInterruptionDaoMixin on DatabaseAccessor<AppDatabase> {
  $ProjectsTableTable get projectsTable => attachedDatabase.projectsTable;
  $ScheduledTasksTableTable get scheduledTasksTable =>
      attachedDatabase.scheduledTasksTable;
  $SessionTableTable get sessionTable => attachedDatabase.sessionTable;
  $SessionRunningTurnsTableTable get sessionRunningTurnsTable =>
      attachedDatabase.sessionRunningTurnsTable;
  $SessionInterruptionsTableTable get sessionInterruptionsTable =>
      attachedDatabase.sessionInterruptionsTable;
  SessionInterruptionDaoManager get managers =>
      SessionInterruptionDaoManager(this);
}

class SessionInterruptionDaoManager {
  final _$SessionInterruptionDaoMixin _db;
  SessionInterruptionDaoManager(this._db);
  $$ProjectsTableTableTableManager get projectsTable =>
      $$ProjectsTableTableTableManager(_db.attachedDatabase, _db.projectsTable);
  $$ScheduledTasksTableTableTableManager get scheduledTasksTable =>
      $$ScheduledTasksTableTableTableManager(
        _db.attachedDatabase,
        _db.scheduledTasksTable,
      );
  $$SessionTableTableTableManager get sessionTable =>
      $$SessionTableTableTableManager(_db.attachedDatabase, _db.sessionTable);
  $$SessionRunningTurnsTableTableTableManager get sessionRunningTurnsTable =>
      $$SessionRunningTurnsTableTableTableManager(
        _db.attachedDatabase,
        _db.sessionRunningTurnsTable,
      );
  $$SessionInterruptionsTableTableTableManager get sessionInterruptionsTable =>
      $$SessionInterruptionsTableTableTableManager(
        _db.attachedDatabase,
        _db.sessionInterruptionsTable,
      );
}
