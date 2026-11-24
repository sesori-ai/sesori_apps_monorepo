// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_wake_up_dao.dart';

// ignore_for_file: type=lint
mixin _$SessionWakeUpDaoMixin on DatabaseAccessor<AppDatabase> {
  $ProjectsTableTable get projectsTable => attachedDatabase.projectsTable;
  $ScheduledTasksTableTable get scheduledTasksTable =>
      attachedDatabase.scheduledTasksTable;
  $SessionTableTable get sessionTable => attachedDatabase.sessionTable;
  $SessionWakeUpsTableTable get sessionWakeUpsTable =>
      attachedDatabase.sessionWakeUpsTable;
  SessionWakeUpDaoManager get managers => SessionWakeUpDaoManager(this);
}

class SessionWakeUpDaoManager {
  final _$SessionWakeUpDaoMixin _db;
  SessionWakeUpDaoManager(this._db);
  $$ProjectsTableTableTableManager get projectsTable =>
      $$ProjectsTableTableTableManager(_db.attachedDatabase, _db.projectsTable);
  $$ScheduledTasksTableTableTableManager get scheduledTasksTable =>
      $$ScheduledTasksTableTableTableManager(
        _db.attachedDatabase,
        _db.scheduledTasksTable,
      );
  $$SessionTableTableTableManager get sessionTable =>
      $$SessionTableTableTableManager(_db.attachedDatabase, _db.sessionTable);
  $$SessionWakeUpsTableTableTableManager get sessionWakeUpsTable =>
      $$SessionWakeUpsTableTableTableManager(
        _db.attachedDatabase,
        _db.sessionWakeUpsTable,
      );
}
