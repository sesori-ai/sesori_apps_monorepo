// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduled_task_dao.dart';

// ignore_for_file: type=lint
mixin _$ScheduledTaskDaoMixin on DatabaseAccessor<AppDatabase> {
  $ProjectsTableTable get projectsTable => attachedDatabase.projectsTable;
  $SessionTableTable get sessionTable => attachedDatabase.sessionTable;
  $ScheduledTasksTableTable get scheduledTasksTable => attachedDatabase.scheduledTasksTable;
  $ScheduledTaskRunsTableTable get scheduledTaskRunsTable => attachedDatabase.scheduledTaskRunsTable;
  ScheduledTaskDaoManager get managers => ScheduledTaskDaoManager(this);
}

class ScheduledTaskDaoManager {
  final _$ScheduledTaskDaoMixin _db;
  ScheduledTaskDaoManager(this._db);
  $$ProjectsTableTableTableManager get projectsTable =>
      $$ProjectsTableTableTableManager(_db.attachedDatabase, _db.projectsTable);
  $$SessionTableTableTableManager get sessionTable =>
      $$SessionTableTableTableManager(_db.attachedDatabase, _db.sessionTable);
  $$ScheduledTasksTableTableTableManager get scheduledTasksTable => $$ScheduledTasksTableTableTableManager(
    _db.attachedDatabase,
    _db.scheduledTasksTable,
  );
  $$ScheduledTaskRunsTableTableTableManager get scheduledTaskRunsTable => $$ScheduledTaskRunsTableTableTableManager(
    _db.attachedDatabase,
    _db.scheduledTaskRunsTable,
  );
}
