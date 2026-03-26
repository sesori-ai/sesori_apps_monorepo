// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $HiddenProjectsTable extends HiddenProjects
    with TableInfo<$HiddenProjectsTable, HiddenProject> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HiddenProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, projectId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'hidden_projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<HiddenProject> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HiddenProject map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HiddenProject(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
    );
  }

  @override
  $HiddenProjectsTable createAlias(String alias) {
    return $HiddenProjectsTable(attachedDatabase, alias);
  }
}

class HiddenProject extends DataClass implements Insertable<HiddenProject> {
  final int id;
  final String projectId;
  const HiddenProject({required this.id, required this.projectId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_id'] = Variable<String>(projectId);
    return map;
  }

  HiddenProjectsCompanion toCompanion(bool nullToAbsent) {
    return HiddenProjectsCompanion(id: Value(id), projectId: Value(projectId));
  }

  factory HiddenProject.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HiddenProject(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectId': serializer.toJson<String>(projectId),
    };
  }

  HiddenProject copyWith({int? id, String? projectId}) =>
      HiddenProject(id: id ?? this.id, projectId: projectId ?? this.projectId);
  HiddenProject copyWithCompanion(HiddenProjectsCompanion data) {
    return HiddenProject(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HiddenProject(')
          ..write('id: $id, ')
          ..write('projectId: $projectId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, projectId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HiddenProject &&
          other.id == this.id &&
          other.projectId == this.projectId);
}

class HiddenProjectsCompanion extends UpdateCompanion<HiddenProject> {
  final Value<int> id;
  final Value<String> projectId;
  const HiddenProjectsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
  });
  HiddenProjectsCompanion.insert({
    this.id = const Value.absent(),
    required String projectId,
  }) : projectId = Value(projectId);
  static Insertable<HiddenProject> custom({
    Expression<int>? id,
    Expression<String>? projectId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
    });
  }

  HiddenProjectsCompanion copyWith({Value<int>? id, Value<String>? projectId}) {
    return HiddenProjectsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HiddenProjectsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $HiddenProjectsTable hiddenProjects = $HiddenProjectsTable(this);
  late final HiddenProjectsDao hiddenProjectsDao = HiddenProjectsDao(
    this as AppDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [hiddenProjects];
}

typedef $$HiddenProjectsTableCreateCompanionBuilder =
    HiddenProjectsCompanion Function({
      Value<int> id,
      required String projectId,
    });
typedef $$HiddenProjectsTableUpdateCompanionBuilder =
    HiddenProjectsCompanion Function({Value<int> id, Value<String> projectId});

class $$HiddenProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $HiddenProjectsTable> {
  $$HiddenProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HiddenProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $HiddenProjectsTable> {
  $$HiddenProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HiddenProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HiddenProjectsTable> {
  $$HiddenProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);
}

class $$HiddenProjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HiddenProjectsTable,
          HiddenProject,
          $$HiddenProjectsTableFilterComposer,
          $$HiddenProjectsTableOrderingComposer,
          $$HiddenProjectsTableAnnotationComposer,
          $$HiddenProjectsTableCreateCompanionBuilder,
          $$HiddenProjectsTableUpdateCompanionBuilder,
          (
            HiddenProject,
            BaseReferences<_$AppDatabase, $HiddenProjectsTable, HiddenProject>,
          ),
          HiddenProject,
          PrefetchHooks Function()
        > {
  $$HiddenProjectsTableTableManager(
    _$AppDatabase db,
    $HiddenProjectsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HiddenProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HiddenProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HiddenProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
              }) => HiddenProjectsCompanion(id: id, projectId: projectId),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String projectId,
              }) =>
                  HiddenProjectsCompanion.insert(id: id, projectId: projectId),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HiddenProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HiddenProjectsTable,
      HiddenProject,
      $$HiddenProjectsTableFilterComposer,
      $$HiddenProjectsTableOrderingComposer,
      $$HiddenProjectsTableAnnotationComposer,
      $$HiddenProjectsTableCreateCompanionBuilder,
      $$HiddenProjectsTableUpdateCompanionBuilder,
      (
        HiddenProject,
        BaseReferences<_$AppDatabase, $HiddenProjectsTable, HiddenProject>,
      ),
      HiddenProject,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$HiddenProjectsTableTableManager get hiddenProjects =>
      $$HiddenProjectsTableTableManager(_db, _db.hiddenProjects);
}
