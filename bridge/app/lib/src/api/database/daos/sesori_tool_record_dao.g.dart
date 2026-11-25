// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sesori_tool_record_dao.dart';

// ignore_for_file: type=lint
mixin _$SesoriToolRecordDaoMixin on DatabaseAccessor<AppDatabase> {
  $ProjectsTableTable get projectsTable => attachedDatabase.projectsTable;
  $ScheduledTasksTableTable get scheduledTasksTable => attachedDatabase.scheduledTasksTable;
  $SessionTableTable get sessionTable => attachedDatabase.sessionTable;
  $SesoriToolSessionRecordsTableTable get sesoriToolSessionRecordsTable =>
      attachedDatabase.sesoriToolSessionRecordsTable;
  $SesoriToolRecordsTableTable get sesoriToolRecordsTable => attachedDatabase.sesoriToolRecordsTable;
  SesoriToolRecordDaoManager get managers => SesoriToolRecordDaoManager(this);
}

class SesoriToolRecordDaoManager {
  final _$SesoriToolRecordDaoMixin _db;
  SesoriToolRecordDaoManager(this._db);
  $$ProjectsTableTableTableManager get projectsTable =>
      $$ProjectsTableTableTableManager(_db.attachedDatabase, _db.projectsTable);
  $$ScheduledTasksTableTableTableManager get scheduledTasksTable => $$ScheduledTasksTableTableTableManager(
    _db.attachedDatabase,
    _db.scheduledTasksTable,
  );
  $$SessionTableTableTableManager get sessionTable =>
      $$SessionTableTableTableManager(_db.attachedDatabase, _db.sessionTable);
  $$SesoriToolSessionRecordsTableTableTableManager get sesoriToolSessionRecordsTable =>
      $$SesoriToolSessionRecordsTableTableTableManager(
        _db.attachedDatabase,
        _db.sesoriToolSessionRecordsTable,
      );
  $$SesoriToolRecordsTableTableTableManager get sesoriToolRecordsTable => $$SesoriToolRecordsTableTableTableManager(
    _db.attachedDatabase,
    _db.sesoriToolRecordsTable,
  );
}
