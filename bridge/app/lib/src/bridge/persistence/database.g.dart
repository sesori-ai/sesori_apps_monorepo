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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects_table (project_id) ON DELETE CASCADE',
    ),
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

mixin $PullRequestsTableTableToColumns implements Insertable<PullRequestDto> {
  String get projectId;
  int get prNumber;
  String get branchName;
  String get url;
  String get title;
  PrState get state;
  PrMergeableStatus get mergeableStatus;
  PrReviewDecision get reviewDecision;
  PrCheckStatus get checkStatus;
  int get lastCheckedAt;
  int get createdAt;
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['project_id'] = Variable<String>(projectId);
    map['pr_number'] = Variable<int>(prNumber);
    map['branch_name'] = Variable<String>(branchName);
    map['url'] = Variable<String>(url);
    map['title'] = Variable<String>(title);
    {
      map['state'] = Variable<String>(
        $PullRequestsTableTable.$converterstate.toSql(state),
      );
    }
    {
      map['mergeable_status'] = Variable<String>(
        $PullRequestsTableTable.$convertermergeableStatus.toSql(
          mergeableStatus,
        ),
      );
    }
    {
      map['review_decision'] = Variable<String>(
        $PullRequestsTableTable.$converterreviewDecision.toSql(reviewDecision),
      );
    }
    {
      map['check_status'] = Variable<String>(
        $PullRequestsTableTable.$convertercheckStatus.toSql(checkStatus),
      );
    }
    map['last_checked_at'] = Variable<int>(lastCheckedAt);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }
}

class $PullRequestsTableTable extends PullRequestsTable
    with TableInfo<$PullRequestsTableTable, PullRequestDto> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PullRequestsTableTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects_table (project_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _prNumberMeta = const VerificationMeta(
    'prNumber',
  );
  @override
  late final GeneratedColumn<int> prNumber = GeneratedColumn<int>(
    'pr_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<PrState, String> state =
      GeneratedColumn<String>(
        'state',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<PrState>($PullRequestsTableTable.$converterstate);
  @override
  late final GeneratedColumnWithTypeConverter<PrMergeableStatus, String>
  mergeableStatus =
      GeneratedColumn<String>(
        'mergeable_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<PrMergeableStatus>(
        $PullRequestsTableTable.$convertermergeableStatus,
      );
  @override
  late final GeneratedColumnWithTypeConverter<PrReviewDecision, String>
  reviewDecision =
      GeneratedColumn<String>(
        'review_decision',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<PrReviewDecision>(
        $PullRequestsTableTable.$converterreviewDecision,
      );
  @override
  late final GeneratedColumnWithTypeConverter<PrCheckStatus, String>
  checkStatus = GeneratedColumn<String>(
    'check_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<PrCheckStatus>($PullRequestsTableTable.$convertercheckStatus);
  static const VerificationMeta _lastCheckedAtMeta = const VerificationMeta(
    'lastCheckedAt',
  );
  @override
  late final GeneratedColumn<int> lastCheckedAt = GeneratedColumn<int>(
    'last_checked_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
    projectId,
    prNumber,
    branchName,
    url,
    title,
    state,
    mergeableStatus,
    reviewDecision,
    checkStatus,
    lastCheckedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pull_requests_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<PullRequestDto> instance, {
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
    if (data.containsKey('pr_number')) {
      context.handle(
        _prNumberMeta,
        prNumber.isAcceptableOrUnknown(data['pr_number']!, _prNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_prNumberMeta);
    }
    if (data.containsKey('branch_name')) {
      context.handle(
        _branchNameMeta,
        branchName.isAcceptableOrUnknown(data['branch_name']!, _branchNameMeta),
      );
    } else if (isInserting) {
      context.missing(_branchNameMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('last_checked_at')) {
      context.handle(
        _lastCheckedAtMeta,
        lastCheckedAt.isAcceptableOrUnknown(
          data['last_checked_at']!,
          _lastCheckedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastCheckedAtMeta);
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
  Set<GeneratedColumn> get $primaryKey => {projectId, prNumber};
  @override
  PullRequestDto map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PullRequestDto(
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      prNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pr_number'],
      )!,
      branchName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_name'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      state: $PullRequestsTableTable.$converterstate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}state'],
        )!,
      ),
      mergeableStatus: $PullRequestsTableTable.$convertermergeableStatus
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}mergeable_status'],
            )!,
          ),
      reviewDecision: $PullRequestsTableTable.$converterreviewDecision.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}review_decision'],
        )!,
      ),
      checkStatus: $PullRequestsTableTable.$convertercheckStatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}check_status'],
        )!,
      ),
      lastCheckedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_checked_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PullRequestsTableTable createAlias(String alias) {
    return $PullRequestsTableTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PrState, String, String> $converterstate =
      const EnumNameConverter<PrState>(PrState.values);
  static JsonTypeConverter2<PrMergeableStatus, String, String>
  $convertermergeableStatus = const EnumNameConverter<PrMergeableStatus>(
    PrMergeableStatus.values,
  );
  static JsonTypeConverter2<PrReviewDecision, String, String>
  $converterreviewDecision = const EnumNameConverter<PrReviewDecision>(
    PrReviewDecision.values,
  );
  static JsonTypeConverter2<PrCheckStatus, String, String>
  $convertercheckStatus = const EnumNameConverter<PrCheckStatus>(
    PrCheckStatus.values,
  );
  @override
  bool get withoutRowId => true;
}

class PullRequestsTableCompanion extends UpdateCompanion<PullRequestDto> {
  final Value<String> projectId;
  final Value<int> prNumber;
  final Value<String> branchName;
  final Value<String> url;
  final Value<String> title;
  final Value<PrState> state;
  final Value<PrMergeableStatus> mergeableStatus;
  final Value<PrReviewDecision> reviewDecision;
  final Value<PrCheckStatus> checkStatus;
  final Value<int> lastCheckedAt;
  final Value<int> createdAt;
  const PullRequestsTableCompanion({
    this.projectId = const Value.absent(),
    this.prNumber = const Value.absent(),
    this.branchName = const Value.absent(),
    this.url = const Value.absent(),
    this.title = const Value.absent(),
    this.state = const Value.absent(),
    this.mergeableStatus = const Value.absent(),
    this.reviewDecision = const Value.absent(),
    this.checkStatus = const Value.absent(),
    this.lastCheckedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PullRequestsTableCompanion.insert({
    required String projectId,
    required int prNumber,
    required String branchName,
    required String url,
    required String title,
    required PrState state,
    required PrMergeableStatus mergeableStatus,
    required PrReviewDecision reviewDecision,
    required PrCheckStatus checkStatus,
    required int lastCheckedAt,
    required int createdAt,
  }) : projectId = Value(projectId),
       prNumber = Value(prNumber),
       branchName = Value(branchName),
       url = Value(url),
       title = Value(title),
       state = Value(state),
       mergeableStatus = Value(mergeableStatus),
       reviewDecision = Value(reviewDecision),
       checkStatus = Value(checkStatus),
       lastCheckedAt = Value(lastCheckedAt),
       createdAt = Value(createdAt);
  static Insertable<PullRequestDto> custom({
    Expression<String>? projectId,
    Expression<int>? prNumber,
    Expression<String>? branchName,
    Expression<String>? url,
    Expression<String>? title,
    Expression<String>? state,
    Expression<String>? mergeableStatus,
    Expression<String>? reviewDecision,
    Expression<String>? checkStatus,
    Expression<int>? lastCheckedAt,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (projectId != null) 'project_id': projectId,
      if (prNumber != null) 'pr_number': prNumber,
      if (branchName != null) 'branch_name': branchName,
      if (url != null) 'url': url,
      if (title != null) 'title': title,
      if (state != null) 'state': state,
      if (mergeableStatus != null) 'mergeable_status': mergeableStatus,
      if (reviewDecision != null) 'review_decision': reviewDecision,
      if (checkStatus != null) 'check_status': checkStatus,
      if (lastCheckedAt != null) 'last_checked_at': lastCheckedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PullRequestsTableCompanion copyWith({
    Value<String>? projectId,
    Value<int>? prNumber,
    Value<String>? branchName,
    Value<String>? url,
    Value<String>? title,
    Value<PrState>? state,
    Value<PrMergeableStatus>? mergeableStatus,
    Value<PrReviewDecision>? reviewDecision,
    Value<PrCheckStatus>? checkStatus,
    Value<int>? lastCheckedAt,
    Value<int>? createdAt,
  }) {
    return PullRequestsTableCompanion(
      projectId: projectId ?? this.projectId,
      prNumber: prNumber ?? this.prNumber,
      branchName: branchName ?? this.branchName,
      url: url ?? this.url,
      title: title ?? this.title,
      state: state ?? this.state,
      mergeableStatus: mergeableStatus ?? this.mergeableStatus,
      reviewDecision: reviewDecision ?? this.reviewDecision,
      checkStatus: checkStatus ?? this.checkStatus,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (prNumber.present) {
      map['pr_number'] = Variable<int>(prNumber.value);
    }
    if (branchName.present) {
      map['branch_name'] = Variable<String>(branchName.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(
        $PullRequestsTableTable.$converterstate.toSql(state.value),
      );
    }
    if (mergeableStatus.present) {
      map['mergeable_status'] = Variable<String>(
        $PullRequestsTableTable.$convertermergeableStatus.toSql(
          mergeableStatus.value,
        ),
      );
    }
    if (reviewDecision.present) {
      map['review_decision'] = Variable<String>(
        $PullRequestsTableTable.$converterreviewDecision.toSql(
          reviewDecision.value,
        ),
      );
    }
    if (checkStatus.present) {
      map['check_status'] = Variable<String>(
        $PullRequestsTableTable.$convertercheckStatus.toSql(checkStatus.value),
      );
    }
    if (lastCheckedAt.present) {
      map['last_checked_at'] = Variable<int>(lastCheckedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PullRequestsTableCompanion(')
          ..write('projectId: $projectId, ')
          ..write('prNumber: $prNumber, ')
          ..write('branchName: $branchName, ')
          ..write('url: $url, ')
          ..write('title: $title, ')
          ..write('state: $state, ')
          ..write('mergeableStatus: $mergeableStatus, ')
          ..write('reviewDecision: $reviewDecision, ')
          ..write('checkStatus: $checkStatus, ')
          ..write('lastCheckedAt: $lastCheckedAt, ')
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
  late final $PullRequestsTableTable pullRequestsTable =
      $PullRequestsTableTable(this);
  late final ProjectsDao projectsDao = ProjectsDao(this as AppDatabase);
  late final SessionDao sessionDao = SessionDao(this as AppDatabase);
  late final PullRequestDao pullRequestDao = PullRequestDao(
    this as AppDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    projectsTable,
    sessionTable,
    pullRequestsTable,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects_table',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('sessions_table', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects_table',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('pull_requests_table', kind: UpdateKind.delete)],
    ),
  ]);
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

final class $$ProjectsTableTableReferences
    extends BaseReferences<_$AppDatabase, $ProjectsTableTable, ProjectDto> {
  $$ProjectsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$SessionTableTable, List<SessionDto>>
  _sessionTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sessionTable,
    aliasName: $_aliasNameGenerator(
      db.projectsTable.projectId,
      db.sessionTable.projectId,
    ),
  );

  $$SessionTableTableProcessedTableManager get sessionTableRefs {
    final manager = $$SessionTableTableTableManager($_db, $_db.sessionTable)
        .filter(
          (f) => f.projectId.projectId.sqlEquals(
            $_itemColumn<String>('project_id')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(_sessionTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PullRequestsTableTable, List<PullRequestDto>>
  _pullRequestsTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.pullRequestsTable,
        aliasName: $_aliasNameGenerator(
          db.projectsTable.projectId,
          db.pullRequestsTable.projectId,
        ),
      );

  $$PullRequestsTableTableProcessedTableManager get pullRequestsTableRefs {
    final manager =
        $$PullRequestsTableTableTableManager(
          $_db,
          $_db.pullRequestsTable,
        ).filter(
          (f) => f.projectId.projectId.sqlEquals(
            $_itemColumn<String>('project_id')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _pullRequestsTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

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

  Expression<bool> sessionTableRefs(
    Expression<bool> Function($$SessionTableTableFilterComposer f) f,
  ) {
    final $$SessionTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.sessionTable,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionTableTableFilterComposer(
            $db: $db,
            $table: $db.sessionTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> pullRequestsTableRefs(
    Expression<bool> Function($$PullRequestsTableTableFilterComposer f) f,
  ) {
    final $$PullRequestsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.pullRequestsTable,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PullRequestsTableTableFilterComposer(
            $db: $db,
            $table: $db.pullRequestsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
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

  Expression<T> sessionTableRefs<T extends Object>(
    Expression<T> Function($$SessionTableTableAnnotationComposer a) f,
  ) {
    final $$SessionTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.sessionTable,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionTableTableAnnotationComposer(
            $db: $db,
            $table: $db.sessionTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> pullRequestsTableRefs<T extends Object>(
    Expression<T> Function($$PullRequestsTableTableAnnotationComposer a) f,
  ) {
    final $$PullRequestsTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.projectId,
          referencedTable: $db.pullRequestsTable,
          getReferencedColumn: (t) => t.projectId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PullRequestsTableTableAnnotationComposer(
                $db: $db,
                $table: $db.pullRequestsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
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
          (ProjectDto, $$ProjectsTableTableReferences),
          ProjectDto,
          PrefetchHooks Function({
            bool sessionTableRefs,
            bool pullRequestsTableRefs,
          })
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
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProjectsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({sessionTableRefs = false, pullRequestsTableRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (sessionTableRefs) db.sessionTable,
                    if (pullRequestsTableRefs) db.pullRequestsTable,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (sessionTableRefs)
                        await $_getPrefetchedData<
                          ProjectDto,
                          $ProjectsTableTable,
                          SessionDto
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableTableReferences
                              ._sessionTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableTableReferences(
                                db,
                                table,
                                p0,
                              ).sessionTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.projectId,
                              ),
                          typedResults: items,
                        ),
                      if (pullRequestsTableRefs)
                        await $_getPrefetchedData<
                          ProjectDto,
                          $ProjectsTableTable,
                          PullRequestDto
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableTableReferences
                              ._pullRequestsTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableTableReferences(
                                db,
                                table,
                                p0,
                              ).pullRequestsTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.projectId,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
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
      (ProjectDto, $$ProjectsTableTableReferences),
      ProjectDto,
      PrefetchHooks Function({
        bool sessionTableRefs,
        bool pullRequestsTableRefs,
      })
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

final class $$SessionTableTableReferences
    extends BaseReferences<_$AppDatabase, $SessionTableTable, SessionDto> {
  $$SessionTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTableTable _projectIdTable(_$AppDatabase db) =>
      db.projectsTable.createAlias(
        $_aliasNameGenerator(
          db.sessionTable.projectId,
          db.projectsTable.projectId,
        ),
      );

  $$ProjectsTableTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableTableManager(
      $_db,
      $_db.projectsTable,
    ).filter((f) => f.projectId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

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

  $$ProjectsTableTableFilterComposer get projectId {
    final $$ProjectsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projectsTable,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableTableFilterComposer(
            $db: $db,
            $table: $db.projectsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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

  $$ProjectsTableTableOrderingComposer get projectId {
    final $$ProjectsTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projectsTable,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableTableOrderingComposer(
            $db: $db,
            $table: $db.projectsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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

  $$ProjectsTableTableAnnotationComposer get projectId {
    final $$ProjectsTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projectsTable,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableTableAnnotationComposer(
            $db: $db,
            $table: $db.projectsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
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
          (SessionDto, $$SessionTableTableReferences),
          SessionDto,
          PrefetchHooks Function({bool projectId})
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
              .map(
                (e) => (
                  e.readTable(table),
                  $$SessionTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable: $$SessionTableTableReferences
                                    ._projectIdTable(db),
                                referencedColumn: $$SessionTableTableReferences
                                    ._projectIdTable(db)
                                    .projectId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
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
      (SessionDto, $$SessionTableTableReferences),
      SessionDto,
      PrefetchHooks Function({bool projectId})
    >;
typedef $$PullRequestsTableTableCreateCompanionBuilder =
    PullRequestsTableCompanion Function({
      required String projectId,
      required int prNumber,
      required String branchName,
      required String url,
      required String title,
      required PrState state,
      required PrMergeableStatus mergeableStatus,
      required PrReviewDecision reviewDecision,
      required PrCheckStatus checkStatus,
      required int lastCheckedAt,
      required int createdAt,
    });
typedef $$PullRequestsTableTableUpdateCompanionBuilder =
    PullRequestsTableCompanion Function({
      Value<String> projectId,
      Value<int> prNumber,
      Value<String> branchName,
      Value<String> url,
      Value<String> title,
      Value<PrState> state,
      Value<PrMergeableStatus> mergeableStatus,
      Value<PrReviewDecision> reviewDecision,
      Value<PrCheckStatus> checkStatus,
      Value<int> lastCheckedAt,
      Value<int> createdAt,
    });

final class $$PullRequestsTableTableReferences
    extends
        BaseReferences<_$AppDatabase, $PullRequestsTableTable, PullRequestDto> {
  $$PullRequestsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProjectsTableTable _projectIdTable(_$AppDatabase db) =>
      db.projectsTable.createAlias(
        $_aliasNameGenerator(
          db.pullRequestsTable.projectId,
          db.projectsTable.projectId,
        ),
      );

  $$ProjectsTableTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableTableManager(
      $_db,
      $_db.projectsTable,
    ).filter((f) => f.projectId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PullRequestsTableTableFilterComposer
    extends Composer<_$AppDatabase, $PullRequestsTableTable> {
  $$PullRequestsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get prNumber => $composableBuilder(
    column: $table.prNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get branchName => $composableBuilder(
    column: $table.branchName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PrState, PrState, String> get state =>
      $composableBuilder(
        column: $table.state,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<PrMergeableStatus, PrMergeableStatus, String>
  get mergeableStatus => $composableBuilder(
    column: $table.mergeableStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<PrReviewDecision, PrReviewDecision, String>
  get reviewDecision => $composableBuilder(
    column: $table.reviewDecision,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<PrCheckStatus, PrCheckStatus, String>
  get checkStatus => $composableBuilder(
    column: $table.checkStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get lastCheckedAt => $composableBuilder(
    column: $table.lastCheckedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableTableFilterComposer get projectId {
    final $$ProjectsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projectsTable,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableTableFilterComposer(
            $db: $db,
            $table: $db.projectsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PullRequestsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $PullRequestsTableTable> {
  $$PullRequestsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get prNumber => $composableBuilder(
    column: $table.prNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get branchName => $composableBuilder(
    column: $table.branchName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mergeableStatus => $composableBuilder(
    column: $table.mergeableStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reviewDecision => $composableBuilder(
    column: $table.reviewDecision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checkStatus => $composableBuilder(
    column: $table.checkStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastCheckedAt => $composableBuilder(
    column: $table.lastCheckedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableTableOrderingComposer get projectId {
    final $$ProjectsTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projectsTable,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableTableOrderingComposer(
            $db: $db,
            $table: $db.projectsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PullRequestsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $PullRequestsTableTable> {
  $$PullRequestsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get prNumber =>
      $composableBuilder(column: $table.prNumber, builder: (column) => column);

  GeneratedColumn<String> get branchName => $composableBuilder(
    column: $table.branchName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PrState, String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PrMergeableStatus, String>
  get mergeableStatus => $composableBuilder(
    column: $table.mergeableStatus,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<PrReviewDecision, String>
  get reviewDecision => $composableBuilder(
    column: $table.reviewDecision,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<PrCheckStatus, String> get checkStatus =>
      $composableBuilder(
        column: $table.checkStatus,
        builder: (column) => column,
      );

  GeneratedColumn<int> get lastCheckedAt => $composableBuilder(
    column: $table.lastCheckedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ProjectsTableTableAnnotationComposer get projectId {
    final $$ProjectsTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projectsTable,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableTableAnnotationComposer(
            $db: $db,
            $table: $db.projectsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PullRequestsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PullRequestsTableTable,
          PullRequestDto,
          $$PullRequestsTableTableFilterComposer,
          $$PullRequestsTableTableOrderingComposer,
          $$PullRequestsTableTableAnnotationComposer,
          $$PullRequestsTableTableCreateCompanionBuilder,
          $$PullRequestsTableTableUpdateCompanionBuilder,
          (PullRequestDto, $$PullRequestsTableTableReferences),
          PullRequestDto,
          PrefetchHooks Function({bool projectId})
        > {
  $$PullRequestsTableTableTableManager(
    _$AppDatabase db,
    $PullRequestsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PullRequestsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PullRequestsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PullRequestsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> projectId = const Value.absent(),
                Value<int> prNumber = const Value.absent(),
                Value<String> branchName = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<PrState> state = const Value.absent(),
                Value<PrMergeableStatus> mergeableStatus = const Value.absent(),
                Value<PrReviewDecision> reviewDecision = const Value.absent(),
                Value<PrCheckStatus> checkStatus = const Value.absent(),
                Value<int> lastCheckedAt = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => PullRequestsTableCompanion(
                projectId: projectId,
                prNumber: prNumber,
                branchName: branchName,
                url: url,
                title: title,
                state: state,
                mergeableStatus: mergeableStatus,
                reviewDecision: reviewDecision,
                checkStatus: checkStatus,
                lastCheckedAt: lastCheckedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                required String projectId,
                required int prNumber,
                required String branchName,
                required String url,
                required String title,
                required PrState state,
                required PrMergeableStatus mergeableStatus,
                required PrReviewDecision reviewDecision,
                required PrCheckStatus checkStatus,
                required int lastCheckedAt,
                required int createdAt,
              }) => PullRequestsTableCompanion.insert(
                projectId: projectId,
                prNumber: prNumber,
                branchName: branchName,
                url: url,
                title: title,
                state: state,
                mergeableStatus: mergeableStatus,
                reviewDecision: reviewDecision,
                checkStatus: checkStatus,
                lastCheckedAt: lastCheckedAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PullRequestsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable:
                                    $$PullRequestsTableTableReferences
                                        ._projectIdTable(db),
                                referencedColumn:
                                    $$PullRequestsTableTableReferences
                                        ._projectIdTable(db)
                                        .projectId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PullRequestsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PullRequestsTableTable,
      PullRequestDto,
      $$PullRequestsTableTableFilterComposer,
      $$PullRequestsTableTableOrderingComposer,
      $$PullRequestsTableTableAnnotationComposer,
      $$PullRequestsTableTableCreateCompanionBuilder,
      $$PullRequestsTableTableUpdateCompanionBuilder,
      (PullRequestDto, $$PullRequestsTableTableReferences),
      PullRequestDto,
      PrefetchHooks Function({bool projectId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProjectsTableTableTableManager get projectsTable =>
      $$ProjectsTableTableTableManager(_db, _db.projectsTable);
  $$SessionTableTableTableManager get sessionTable =>
      $$SessionTableTableTableManager(_db, _db.sessionTable);
  $$PullRequestsTableTableTableManager get pullRequestsTable =>
      $$PullRequestsTableTableTableManager(_db, _db.pullRequestsTable);
}
