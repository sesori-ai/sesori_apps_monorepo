// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
mixin $ProjectsTableTableToColumns implements Insertable<ProjectDto> {
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
    with TableInfo<$ProjectsTableTable, ProjectDto> {
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
    Insertable<ProjectDto> instance, {
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
  ProjectDto map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectDto(
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

class ProjectsTableCompanion extends UpdateCompanion<ProjectDto> {
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
  static Insertable<ProjectDto> custom({
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

mixin $SessionTableTableToColumns implements Insertable<SessionDto> {
  String get sessionId;
  String get projectId;
  String? get worktreePath;
  String? get branchName;
  bool get isDedicated;
  int? get archivedAt;
  String? get baseBranch;
  String? get baseCommit;
  int get createdAt;
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['project_id'] = Variable<String>(projectId);
    if (!nullToAbsent || worktreePath != null) {
      map['worktree_path'] = Variable<String>(worktreePath);
    }
    if (!nullToAbsent || branchName != null) {
      map['branch_name'] = Variable<String>(branchName);
    }
    map['is_dedicated'] = Variable<bool>(isDedicated);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<int>(archivedAt);
    }
    if (!nullToAbsent || baseBranch != null) {
      map['base_branch'] = Variable<String>(baseBranch);
    }
    if (!nullToAbsent || baseCommit != null) {
      map['base_commit'] = Variable<String>(baseCommit);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }
}

class $SessionTableTable extends SessionTable
    with TableInfo<$SessionTableTable, SessionDto> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionTableTable(this.attachedDatabase, [this._alias]);
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _branchNameMeta = const VerificationMeta(
    'branchName',
  );
  @override
  late final GeneratedColumn<String> branchName = GeneratedColumn<String>(
    'branch_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDedicatedMeta = const VerificationMeta(
    'isDedicated',
  );
  @override
  late final GeneratedColumn<bool> isDedicated = GeneratedColumn<bool>(
    'is_dedicated',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_dedicated" IN (0, 1))',
    ),
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<int> archivedAt = GeneratedColumn<int>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
  static const VerificationMeta _baseCommitMeta = const VerificationMeta(
    'baseCommit',
  );
  @override
  late final GeneratedColumn<String> baseCommit = GeneratedColumn<String>(
    'base_commit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    projectId,
    worktreePath,
    branchName,
    isDedicated,
    archivedAt,
    baseBranch,
    baseCommit,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionDto> instance, {
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
    }
    if (data.containsKey('branch_name')) {
      context.handle(
        _branchNameMeta,
        branchName.isAcceptableOrUnknown(data['branch_name']!, _branchNameMeta),
      );
    }
    if (data.containsKey('is_dedicated')) {
      context.handle(
        _isDedicatedMeta,
        isDedicated.isAcceptableOrUnknown(
          data['is_dedicated']!,
          _isDedicatedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_isDedicatedMeta);
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('base_branch')) {
      context.handle(
        _baseBranchMeta,
        baseBranch.isAcceptableOrUnknown(data['base_branch']!, _baseBranchMeta),
      );
    }
    if (data.containsKey('base_commit')) {
      context.handle(
        _baseCommitMeta,
        baseCommit.isAcceptableOrUnknown(data['base_commit']!, _baseCommitMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  SessionDto map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionDto(
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
      ),
      branchName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_name'],
      ),
      isDedicated: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_dedicated'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}archived_at'],
      ),
      baseBranch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_branch'],
      ),
      baseCommit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_commit'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SessionTableTable createAlias(String alias) {
    return $SessionTableTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class SessionTableCompanion extends UpdateCompanion<SessionDto> {
  final Value<String> sessionId;
  final Value<String> projectId;
  final Value<String?> worktreePath;
  final Value<String?> branchName;
  final Value<bool> isDedicated;
  final Value<int?> archivedAt;
  final Value<String?> baseBranch;
  final Value<String?> baseCommit;
  final Value<int> createdAt;
  const SessionTableCompanion({
    this.sessionId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.worktreePath = const Value.absent(),
    this.branchName = const Value.absent(),
    this.isDedicated = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.baseBranch = const Value.absent(),
    this.baseCommit = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SessionTableCompanion.insert({
    required String sessionId,
    required String projectId,
    this.worktreePath = const Value.absent(),
    this.branchName = const Value.absent(),
    required bool isDedicated,
    this.archivedAt = const Value.absent(),
    this.baseBranch = const Value.absent(),
    this.baseCommit = const Value.absent(),
    required int createdAt,
  }) : sessionId = Value(sessionId),
       projectId = Value(projectId),
       isDedicated = Value(isDedicated),
       createdAt = Value(createdAt);
  static Insertable<SessionDto> custom({
    Expression<String>? sessionId,
    Expression<String>? projectId,
    Expression<String>? worktreePath,
    Expression<String>? branchName,
    Expression<bool>? isDedicated,
    Expression<int>? archivedAt,
    Expression<String>? baseBranch,
    Expression<String>? baseCommit,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (projectId != null) 'project_id': projectId,
      if (worktreePath != null) 'worktree_path': worktreePath,
      if (branchName != null) 'branch_name': branchName,
      if (isDedicated != null) 'is_dedicated': isDedicated,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (baseBranch != null) 'base_branch': baseBranch,
      if (baseCommit != null) 'base_commit': baseCommit,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SessionTableCompanion copyWith({
    Value<String>? sessionId,
    Value<String>? projectId,
    Value<String?>? worktreePath,
    Value<String?>? branchName,
    Value<bool>? isDedicated,
    Value<int?>? archivedAt,
    Value<String?>? baseBranch,
    Value<String?>? baseCommit,
    Value<int>? createdAt,
  }) {
    return SessionTableCompanion(
      sessionId: sessionId ?? this.sessionId,
      projectId: projectId ?? this.projectId,
      worktreePath: worktreePath ?? this.worktreePath,
      branchName: branchName ?? this.branchName,
      isDedicated: isDedicated ?? this.isDedicated,
      archivedAt: archivedAt ?? this.archivedAt,
      baseBranch: baseBranch ?? this.baseBranch,
      baseCommit: baseCommit ?? this.baseCommit,
      createdAt: createdAt ?? this.createdAt,
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
    if (isDedicated.present) {
      map['is_dedicated'] = Variable<bool>(isDedicated.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<int>(archivedAt.value);
    }
    if (baseBranch.present) {
      map['base_branch'] = Variable<String>(baseBranch.value);
    }
    if (baseCommit.present) {
      map['base_commit'] = Variable<String>(baseCommit.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionTableCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('projectId: $projectId, ')
          ..write('worktreePath: $worktreePath, ')
          ..write('branchName: $branchName, ')
          ..write('isDedicated: $isDedicated, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('baseBranch: $baseBranch, ')
          ..write('baseCommit: $baseCommit, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProjectsTableTable projectsTable = $ProjectsTableTable(this);
  late final $SessionTableTable sessionTable = $SessionTableTable(this);
  late final ProjectsDao projectsDao = ProjectsDao(this as AppDatabase);
  late final SessionDao sessionDao = SessionDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    projectsTable,
    sessionTable,
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
          ProjectDto,
          $$ProjectsTableTableFilterComposer,
          $$ProjectsTableTableOrderingComposer,
          $$ProjectsTableTableAnnotationComposer,
          $$ProjectsTableTableCreateCompanionBuilder,
          $$ProjectsTableTableUpdateCompanionBuilder,
          (
            ProjectDto,
            BaseReferences<_$AppDatabase, $ProjectsTableTable, ProjectDto>,
          ),
          ProjectDto,
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
      ProjectDto,
      $$ProjectsTableTableFilterComposer,
      $$ProjectsTableTableOrderingComposer,
      $$ProjectsTableTableAnnotationComposer,
      $$ProjectsTableTableCreateCompanionBuilder,
      $$ProjectsTableTableUpdateCompanionBuilder,
      (
        ProjectDto,
        BaseReferences<_$AppDatabase, $ProjectsTableTable, ProjectDto>,
      ),
      ProjectDto,
      PrefetchHooks Function()
    >;
typedef $$SessionTableTableCreateCompanionBuilder =
    SessionTableCompanion Function({
      required String sessionId,
      required String projectId,
      Value<String?> worktreePath,
      Value<String?> branchName,
      required bool isDedicated,
      Value<int?> archivedAt,
      Value<String?> baseBranch,
      Value<String?> baseCommit,
      required int createdAt,
    });
typedef $$SessionTableTableUpdateCompanionBuilder =
    SessionTableCompanion Function({
      Value<String> sessionId,
      Value<String> projectId,
      Value<String?> worktreePath,
      Value<String?> branchName,
      Value<bool> isDedicated,
      Value<int?> archivedAt,
      Value<String?> baseBranch,
      Value<String?> baseCommit,
      Value<int> createdAt,
    });

class $$SessionTableTableFilterComposer
    extends Composer<_$AppDatabase, $SessionTableTable> {
  $$SessionTableTableFilterComposer({
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

  ColumnFilters<bool> get isDedicated => $composableBuilder(
    column: $table.isDedicated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseBranch => $composableBuilder(
    column: $table.baseBranch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseCommit => $composableBuilder(
    column: $table.baseCommit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionTableTable> {
  $$SessionTableTableOrderingComposer({
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

  ColumnOrderings<bool> get isDedicated => $composableBuilder(
    column: $table.isDedicated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseBranch => $composableBuilder(
    column: $table.baseBranch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseCommit => $composableBuilder(
    column: $table.baseCommit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionTableTable> {
  $$SessionTableTableAnnotationComposer({
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

  GeneratedColumn<bool> get isDedicated => $composableBuilder(
    column: $table.isDedicated,
    builder: (column) => column,
  );

  GeneratedColumn<int> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baseBranch => $composableBuilder(
    column: $table.baseBranch,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baseCommit => $composableBuilder(
    column: $table.baseCommit,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SessionTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionTableTable,
          SessionDto,
          $$SessionTableTableFilterComposer,
          $$SessionTableTableOrderingComposer,
          $$SessionTableTableAnnotationComposer,
          $$SessionTableTableCreateCompanionBuilder,
          $$SessionTableTableUpdateCompanionBuilder,
          (
            SessionDto,
            BaseReferences<_$AppDatabase, $SessionTableTable, SessionDto>,
          ),
          SessionDto,
          PrefetchHooks Function()
        > {
  $$SessionTableTableTableManager(_$AppDatabase db, $SessionTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String?> worktreePath = const Value.absent(),
                Value<String?> branchName = const Value.absent(),
                Value<bool> isDedicated = const Value.absent(),
                Value<int?> archivedAt = const Value.absent(),
                Value<String?> baseBranch = const Value.absent(),
                Value<String?> baseCommit = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => SessionTableCompanion(
                sessionId: sessionId,
                projectId: projectId,
                worktreePath: worktreePath,
                branchName: branchName,
                isDedicated: isDedicated,
                archivedAt: archivedAt,
                baseBranch: baseBranch,
                baseCommit: baseCommit,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required String projectId,
                Value<String?> worktreePath = const Value.absent(),
                Value<String?> branchName = const Value.absent(),
                required bool isDedicated,
                Value<int?> archivedAt = const Value.absent(),
                Value<String?> baseBranch = const Value.absent(),
                Value<String?> baseCommit = const Value.absent(),
                required int createdAt,
              }) => SessionTableCompanion.insert(
                sessionId: sessionId,
                projectId: projectId,
                worktreePath: worktreePath,
                branchName: branchName,
                isDedicated: isDedicated,
                archivedAt: archivedAt,
                baseBranch: baseBranch,
                baseCommit: baseCommit,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionTableTable,
      SessionDto,
      $$SessionTableTableFilterComposer,
      $$SessionTableTableOrderingComposer,
      $$SessionTableTableAnnotationComposer,
      $$SessionTableTableCreateCompanionBuilder,
      $$SessionTableTableUpdateCompanionBuilder,
      (
        SessionDto,
        BaseReferences<_$AppDatabase, $SessionTableTable, SessionDto>,
      ),
      SessionDto,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProjectsTableTableTableManager get projectsTable =>
      $$ProjectsTableTableTableManager(_db, _db.projectsTable);
  $$SessionTableTableTableManager get sessionTable =>
      $$SessionTableTableTableManager(_db, _db.sessionTable);
}
