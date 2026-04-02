// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pull_request_dao.dart';

// ignore_for_file: type=lint
mixin _$PullRequestDaoMixin on DatabaseAccessor<AppDatabase> {
  $SessionTableTable get sessionTable => attachedDatabase.sessionTable;
  $PullRequestsTableTable get pullRequestsTable =>
      attachedDatabase.pullRequestsTable;
  PullRequestDaoManager get managers => PullRequestDaoManager(this);
}

class PullRequestDaoManager {
  final _$PullRequestDaoMixin _db;
  PullRequestDaoManager(this._db);
  $$SessionTableTableTableManager get sessionTable =>
      $$SessionTableTableTableManager(_db.attachedDatabase, _db.sessionTable);
  $$PullRequestsTableTableTableManager get pullRequestsTable =>
      $$PullRequestsTableTableTableManager(
        _db.attachedDatabase,
        _db.pullRequestsTable,
      );
}
