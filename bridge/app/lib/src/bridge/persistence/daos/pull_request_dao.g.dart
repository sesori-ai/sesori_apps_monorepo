// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pull_request_dao.dart';

// ignore_for_file: type=lint
mixin _$PullRequestDaoMixin on DatabaseAccessor<AppDatabase> {
  $ProjectsTableTable get projectsTable => attachedDatabase.projectsTable;
  $PullRequestsTableTable get pullRequestsTable =>
      attachedDatabase.pullRequestsTable;
  $SessionTableTable get sessionTable => attachedDatabase.sessionTable;
  PullRequestDaoManager get managers => PullRequestDaoManager(this);
}

class PullRequestDaoManager {
  final _$PullRequestDaoMixin _db;
  PullRequestDaoManager(this._db);
  $$ProjectsTableTableTableManager get projectsTable =>
      $$ProjectsTableTableTableManager(_db.attachedDatabase, _db.projectsTable);
  $$PullRequestsTableTableTableManager get pullRequestsTable =>
      $$PullRequestsTableTableTableManager(
        _db.attachedDatabase,
        _db.pullRequestsTable,
      );
  $$SessionTableTableTableManager get sessionTable =>
      $$SessionTableTableTableManager(_db.attachedDatabase, _db.sessionTable);
}
