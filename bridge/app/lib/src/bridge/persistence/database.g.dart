// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
mixin $ProjectsTableTableToColumns implements Insertable<Project> {
  String get projectId;
  bool get hidden;
  String? get baseBranch;
  int get worktreeCounter;
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['project_id'] = Variable<String>(projectId);
    map['hidden'] = Variable<bool>(hidden);
    if (!nullToAbsent || baseBranch != null) {
      map['base_branch'] = Variable<String>(baseBranch);
    }
    map['worktree_counter'] = Variable<int>(worktreeCounter);
    return map;
  }
}

class $ProjectsTableTable extends ProjectsTable
    with TableInfo<$ProjectsTableTable, Project> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTableTable(this.attachedDatabase, [this._alias]);
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
  );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _baseBranchMeta = const VerificationMeta(
    'baseBranch',
  );
  @override
  late final GeneratedColumn<String> baseBranch = GeneratedColumn<String>(
    'base_branch',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _worktreeCounterMeta = const VerificationMeta(
    'worktreeCounter',
  );
  @override
  late final GeneratedColumn<int> worktreeCounter = GeneratedColumn<int>(
    'worktree_counter',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    projectId,
    hidden,
    baseBranch,
    worktreeCounter,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<Project> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    }
    if (data.containsKey('base_branch')) {
      context.handle(
        _baseBranchMeta,
        baseBranch.isAcceptableOrUnknown(data['base_branch']!, _baseBranchMeta),
      );
    }
    if (data.containsKey('worktree_counter')) {
      context.handle(
        _worktreeCounterMeta,
        worktreeCounter.isAcceptableOrUnknown(
          data['worktree_counter']!,
          _worktreeCounterMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {projectId};
  @override
  Project map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Project(
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
      baseBranch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_branch'],
      ),
      worktreeCounter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}worktree_counter'],
      )!,
    );
  }

  @override
  $ProjectsTableTable createAlias(String alias) {
    return $ProjectsTableTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class ProjectsTableCompanion extends UpdateCompanion<Project> {
  final Value<String> projectId;
  final Value<bool> hidden;
  final Value<String?> baseBranch;
  final Value<int> worktreeCounter;
  const ProjectsTableCompanion({
    this.projectId = const Value.absent(),
    this.hidden = const Value.absent(),
    this.baseBranch = const Value.absent(),
    this.worktreeCounter = const Value.absent(),
  });
  ProjectsTableCompanion.insert({
    required String projectId,
    this.hidden = const Value.absent(),
    this.baseBranch = const Value.absent(),
    this.worktreeCounter = const Value.absent(),
  }) : projectId = Value(projectId);
  static Insertable<Project> custom({
    Expression<String>? projectId,
    Expression<bool>? hidden,
    Expression<String>? baseBranch,
    Expression<int>? worktreeCounter,
  }) {
    return RawValuesInsertable({
      if (projectId != null) 'project_id': projectId,
      if (hidden != null) 'hidden': hidden,
      if (baseBranch != null) 'base_branch': baseBranch,
      if (worktreeCounter != null) 'worktree_counter': worktreeCounter,
    });
  }

  ProjectsTableCompanion copyWith({
    Value<String>? projectId,
    Value<bool>? hidden,
    Value<String?>? baseBranch,
    Value<int>? worktreeCounter,
  }) {
    return ProjectsTableCompanion(
      projectId: projectId ?? this.projectId,
      hidden: hidden ?? this.hidden,
      baseBranch: baseBranch ?? this.baseBranch,
      worktreeCounter: worktreeCounter ?? this.worktreeCounter,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (baseBranch.present) {
      map['base_branch'] = Variable<String>(baseBranch.value);
    }
    if (worktreeCounter.present) {
      map['worktree_counter'] = Variable<int>(worktreeCounter.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsTableCompanion(')
          ..write('projectId: $projectId, ')
          ..write('hidden: $hidden, ')
          ..write('baseBranch: $baseBranch, ')
          ..write('worktreeCounter: $worktreeCounter')
          ..write(')'))
        .toString();
  }
}

mixin $SessionWorktreesTableTableToColumns
    implements Insertable<SessionWorktree> {
  String get sessionId;
  String get projectId;
  String get worktreePath;
  String get branchName;
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['project_id'] = Variable<String>(projectId);
    map['worktree_path'] = Variable<String>(worktreePath);
    map['branch_name'] = Variable<String>(branchName);
    return map;
  }
}

class $SessionWorktreesTableTable extends SessionWorktreesTable
    with TableInfo<$SessionWorktreesTableTable, SessionWorktree> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionWorktreesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  );
  static const VerificationMeta _worktreePathMeta = const VerificationMeta(
    'worktreePath',
  );
  @override
  late final GeneratedColumn<String> worktreePath = GeneratedColumn<String>(
    'worktree_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _branchNameMeta = const VerificationMeta(
    'branchName',
  );
  @override
  late final GeneratedColumn<String> branchName = GeneratedColumn<String>(
    'branch_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    projectId,
    worktreePath,
    branchName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_worktrees_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionWorktree> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('worktree_path')) {
      context.handle(
        _worktreePathMeta,
        worktreePath.isAcceptableOrUnknown(
          data['worktree_path']!,
          _worktreePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_worktreePathMeta);
    }
    if (data.containsKey('branch_name')) {
      context.handle(
        _branchNameMeta,
        branchName.isAcceptableOrUnknown(data['branch_name']!, _branchNameMeta),
      );
    } else if (isInserting) {
      context.missing(_branchNameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  SessionWorktree map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionWorktree(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      worktreePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}worktree_path'],
      )!,
      branchName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_name'],
      )!,
    );
  }

  @override
  $SessionWorktreesTableTable createAlias(String alias) {
    return $SessionWorktreesTableTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class SessionWorktreesTableCompanion extends UpdateCompanion<SessionWorktree> {
  final Value<String> sessionId;
  final Value<String> projectId;
  final Value<String> worktreePath;
  final Value<String> branchName;
  const SessionWorktreesTableCompanion({
    this.sessionId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.worktreePath = const Value.absent(),
    this.branchName = const Value.absent(),
  });
  SessionWorktreesTableCompanion.insert({
    required String sessionId,
    required String projectId,
    required String worktreePath,
    required String branchName,
  }) : sessionId = Value(sessionId),
       projectId = Value(projectId),
       worktreePath = Value(worktreePath),
       branchName = Value(branchName);
  static Insertable<SessionWorktree> custom({
    Expression<String>? sessionId,
    Expression<String>? projectId,
    Expression<String>? worktreePath,
    Expression<String>? branchName,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (projectId != null) 'project_id': projectId,
      if (worktreePath != null) 'worktree_path': worktreePath,
      if (branchName != null) 'branch_name': branchName,
    });
  }

  SessionWorktreesTableCompanion copyWith({
    Value<String>? sessionId,
    Value<String>? projectId,
    Value<String>? worktreePath,
    Value<String>? branchName,
  }) {
    return SessionWorktreesTableCompanion(
      sessionId: sessionId ?? this.sessionId,
      projectId: projectId ?? this.projectId,
      worktreePath: worktreePath ?? this.worktreePath,
      branchName: branchName ?? this.branchName,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (worktreePath.present) {
      map['worktree_path'] = Variable<String>(worktreePath.value);
    }
    if (branchName.present) {
      map['branch_name'] = Variable<String>(branchName.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionWorktreesTableCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('projectId: $projectId, ')
          ..write('worktreePath: $worktreePath, ')
          ..write('branchName: $branchName')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProjectsTableTable projectsTable = $ProjectsTableTable(this);
  late final $SessionWorktreesTableTable sessionWorktreesTable =
      $SessionWorktreesTableTable(this);
  late final ProjectsDao projectsDao = ProjectsDao(this as AppDatabase);
  late final SessionWorktreesDao sessionWorktreesDao = SessionWorktreesDao(
    this as AppDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    projectsTable,
    sessionWorktreesTable,
  ];
}

typedef $$ProjectsTableTableCreateCompanionBuilder =
    ProjectsTableCompanion Function({
      required String projectId,
      Value<bool> hidden,
      Value<String?> baseBranch,
      Value<int> worktreeCounter,
    });
typedef $$ProjectsTableTableUpdateCompanionBuilder =
    ProjectsTableCompanion Function({
      Value<String> projectId,
      Value<bool> hidden,
      Value<String?> baseBranch,
      Value<int> worktreeCounter,
    });

class $$ProjectsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectsTableTable> {
  $$ProjectsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseBranch => $composableBuilder(
    column: $table.baseBranch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get worktreeCounter => $composableBuilder(
    column: $table.worktreeCounter,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProjectsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectsTableTable> {
  $$ProjectsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseBranch => $composableBuilder(
    column: $table.baseBranch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get worktreeCounter => $composableBuilder(
    column: $table.worktreeCounter,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProjectsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectsTableTable> {
  $$ProjectsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  GeneratedColumn<String> get baseBranch => $composableBuilder(
    column: $table.baseBranch,
    builder: (column) => column,
  );

  GeneratedColumn<int> get worktreeCounter => $composableBuilder(
    column: $table.worktreeCounter,
    builder: (column) => column,
  );
}

class $$ProjectsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectsTableTable,
          Project,
          $$ProjectsTableTableFilterComposer,
          $$ProjectsTableTableOrderingComposer,
          $$ProjectsTableTableAnnotationComposer,
          $$ProjectsTableTableCreateCompanionBuilder,
          $$ProjectsTableTableUpdateCompanionBuilder,
          (
            Project,
            BaseReferences<_$AppDatabase, $ProjectsTableTable, Project>,
          ),
          Project,
          PrefetchHooks Function()
        > {
  $$ProjectsTableTableTableManager(_$AppDatabase db, $ProjectsTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> projectId = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<String?> baseBranch = const Value.absent(),
                Value<int> worktreeCounter = const Value.absent(),
              }) => ProjectsTableCompanion(
                projectId: projectId,
                hidden: hidden,
                baseBranch: baseBranch,
                worktreeCounter: worktreeCounter,
              ),
          createCompanionCallback:
              ({
                required String projectId,
                Value<bool> hidden = const Value.absent(),
                Value<String?> baseBranch = const Value.absent(),
                Value<int> worktreeCounter = const Value.absent(),
              }) => ProjectsTableCompanion.insert(
                projectId: projectId,
                hidden: hidden,
                baseBranch: baseBranch,
                worktreeCounter: worktreeCounter,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProjectsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectsTableTable,
      Project,
      $$ProjectsTableTableFilterComposer,
      $$ProjectsTableTableOrderingComposer,
      $$ProjectsTableTableAnnotationComposer,
      $$ProjectsTableTableCreateCompanionBuilder,
      $$ProjectsTableTableUpdateCompanionBuilder,
      (Project, BaseReferences<_$AppDatabase, $ProjectsTableTable, Project>),
      Project,
      PrefetchHooks Function()
    >;
typedef $$SessionWorktreesTableTableCreateCompanionBuilder =
    SessionWorktreesTableCompanion Function({
      required String sessionId,
      required String projectId,
      required String worktreePath,
      required String branchName,
    });
typedef $$SessionWorktreesTableTableUpdateCompanionBuilder =
    SessionWorktreesTableCompanion Function({
      Value<String> sessionId,
      Value<String> projectId,
      Value<String> worktreePath,
      Value<String> branchName,
    });

class $$SessionWorktreesTableTableFilterComposer
    extends Composer<_$AppDatabase, $SessionWorktreesTableTable> {
  $$SessionWorktreesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get worktreePath => $composableBuilder(
    column: $table.worktreePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get branchName => $composableBuilder(
    column: $table.branchName,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionWorktreesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionWorktreesTableTable> {
  $$SessionWorktreesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get worktreePath => $composableBuilder(
    column: $table.worktreePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get branchName => $composableBuilder(
    column: $table.branchName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionWorktreesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionWorktreesTableTable> {
  $$SessionWorktreesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get worktreePath => $composableBuilder(
    column: $table.worktreePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get branchName => $composableBuilder(
    column: $table.branchName,
    builder: (column) => column,
  );
}

class $$SessionWorktreesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionWorktreesTableTable,
          SessionWorktree,
          $$SessionWorktreesTableTableFilterComposer,
          $$SessionWorktreesTableTableOrderingComposer,
          $$SessionWorktreesTableTableAnnotationComposer,
          $$SessionWorktreesTableTableCreateCompanionBuilder,
          $$SessionWorktreesTableTableUpdateCompanionBuilder,
          (
            SessionWorktree,
            BaseReferences<
              _$AppDatabase,
              $SessionWorktreesTableTable,
              SessionWorktree
            >,
          ),
          SessionWorktree,
          PrefetchHooks Function()
        > {
  $$SessionWorktreesTableTableTableManager(
    _$AppDatabase db,
    $SessionWorktreesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionWorktreesTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SessionWorktreesTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SessionWorktreesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> worktreePath = const Value.absent(),
                Value<String> branchName = const Value.absent(),
              }) => SessionWorktreesTableCompanion(
                sessionId: sessionId,
                projectId: projectId,
                worktreePath: worktreePath,
                branchName: branchName,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required String projectId,
                required String worktreePath,
                required String branchName,
              }) => SessionWorktreesTableCompanion.insert(
                sessionId: sessionId,
                projectId: projectId,
                worktreePath: worktreePath,
                branchName: branchName,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionWorktreesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionWorktreesTableTable,
      SessionWorktree,
      $$SessionWorktreesTableTableFilterComposer,
      $$SessionWorktreesTableTableOrderingComposer,
      $$SessionWorktreesTableTableAnnotationComposer,
      $$SessionWorktreesTableTableCreateCompanionBuilder,
      $$SessionWorktreesTableTableUpdateCompanionBuilder,
      (
        SessionWorktree,
        BaseReferences<
          _$AppDatabase,
          $SessionWorktreesTableTable,
          SessionWorktree
        >,
      ),
      SessionWorktree,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProjectsTableTableTableManager get projectsTable =>
      $$ProjectsTableTableTableManager(_db, _db.projectsTable);
  $$SessionWorktreesTableTableTableManager get sessionWorktreesTable =>
      $$SessionWorktreesTableTableTableManager(_db, _db.sessionWorktreesTable);
}
