// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hidden_projects_dao.dart';

// ignore_for_file: type=lint
mixin _$HiddenProjectsDaoMixin on DatabaseAccessor<AppDatabase> {
  $HiddenProjectsTable get hiddenProjects => attachedDatabase.hiddenProjects;
  HiddenProjectsDaoManager get managers => HiddenProjectsDaoManager(this);
}

class HiddenProjectsDaoManager {
  final _$HiddenProjectsDaoMixin _db;
  HiddenProjectsDaoManager(this._db);
  $$HiddenProjectsTableTableManager get hiddenProjects =>
      $$HiddenProjectsTableTableManager(
        _db.attachedDatabase,
        _db.hiddenProjects,
      );
}
