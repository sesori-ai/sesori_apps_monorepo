// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_pages_dao.dart';

// ignore_for_file: type=lint
mixin _$AgentPagesDaoMixin on DatabaseAccessor<AppDatabase> {
  $ProjectsTableTable get projectsTable => attachedDatabase.projectsTable;
  $ScheduledTasksTableTable get scheduledTasksTable => attachedDatabase.scheduledTasksTable;
  $SessionTableTable get sessionTable => attachedDatabase.sessionTable;
  $AgentPagesTableTable get agentPagesTable => attachedDatabase.agentPagesTable;
  AgentPagesDaoManager get managers => AgentPagesDaoManager(this);
}

class AgentPagesDaoManager {
  final _$AgentPagesDaoMixin _db;
  AgentPagesDaoManager(this._db);
  $$ProjectsTableTableTableManager get projectsTable =>
      $$ProjectsTableTableTableManager(_db.attachedDatabase, _db.projectsTable);
  $$ScheduledTasksTableTableTableManager get scheduledTasksTable => $$ScheduledTasksTableTableTableManager(
    _db.attachedDatabase,
    _db.scheduledTasksTable,
  );
  $$SessionTableTableTableManager get sessionTable =>
      $$SessionTableTableTableManager(_db.attachedDatabase, _db.sessionTable);
  $$AgentPagesTableTableTableManager get agentPagesTable => $$AgentPagesTableTableTableManager(
    _db.attachedDatabase,
    _db.agentPagesTable,
  );
}
