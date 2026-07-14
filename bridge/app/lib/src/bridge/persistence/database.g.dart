// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
mixin $ProjectsTableTableToColumns implements Insertable<ProjectDto> {
  String get projectId;

  /// The project's live directory on disk. This may differ from [projectId]
  /// after a folder move; the id remains the stable bridge/client handle.
  String get path;
  bool get hidden;
  String? get baseBranch;
  int get worktreeCounter;

  /// Bridge-persisted display-name override for a renamed project. Used by
  /// bridge-derived plugins, which have no backend to store a project name;
  /// null means fall back to the directory basename.
  String? get displayName;

  /// Wall-clock ms when this project row was first recorded — the folder was
  /// opened or the project was first discovered. Stamped at insert time and
  /// never advanced by later opens; it is the authoritative project creation
  /// time for REST responses.
  int get createdAt;

  /// Wall-clock ms of the last recorded activity for this project. Advanced by
  /// the project-activity service from plugin activity, session evidence, and
  /// user-facing events. The repository writes exact values supplied by the
  /// service and performs no min/max itself.
  int get updatedAt;
  int get projectionUpdatedAt;
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['project_id'] = Variable<String>(projectId);
    map['path'] = Variable<String>(path);
    map['hidden'] = Variable<bool>(hidden);
    if (!nullToAbsent || baseBranch != null) {
      map['base_branch'] = Variable<String>(baseBranch);
    }
    map['worktree_counter'] = Variable<int>(worktreeCounter);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['projection_updated_at'] = Variable<int>(projectionUpdatedAt);
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
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
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
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
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
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now().millisecondsSinceEpoch,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now().millisecondsSinceEpoch,
  );
  static const VerificationMeta _projectionUpdatedAtMeta =
      const VerificationMeta('projectionUpdatedAt');
  @override
  late final GeneratedColumn<int> projectionUpdatedAt = GeneratedColumn<int>(
    'projection_updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    projectId,
    path,
    hidden,
    baseBranch,
    worktreeCounter,
    displayName,
    createdAt,
    updatedAt,
    projectionUpdatedAt,
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
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
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
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('projection_updated_at')) {
      context.handle(
        _projectionUpdatedAtMeta,
        projectionUpdatedAt.isAcceptableOrUnknown(
          data['projection_updated_at']!,
          _projectionUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_projectionUpdatedAtMeta);
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
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
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
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      projectionUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}projection_updated_at'],
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
  final Value<String> path;
  final Value<bool> hidden;
  final Value<String?> baseBranch;
  final Value<int> worktreeCounter;
  final Value<String?> displayName;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> projectionUpdatedAt;
  const ProjectsTableCompanion({
    this.projectId = const Value.absent(),
    this.path = const Value.absent(),
    this.hidden = const Value.absent(),
    this.baseBranch = const Value.absent(),
    this.worktreeCounter = const Value.absent(),
    this.displayName = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.projectionUpdatedAt = const Value.absent(),
  });
  ProjectsTableCompanion.insert({
    required String projectId,
    required String path,
    this.hidden = const Value.absent(),
    this.baseBranch = const Value.absent(),
    this.worktreeCounter = const Value.absent(),
    this.displayName = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    required int projectionUpdatedAt,
  }) : projectId = Value(projectId),
       path = Value(path),
       projectionUpdatedAt = Value(projectionUpdatedAt);
  static Insertable<ProjectDto> custom({
    Expression<String>? projectId,
    Expression<String>? path,
    Expression<bool>? hidden,
    Expression<String>? baseBranch,
    Expression<int>? worktreeCounter,
    Expression<String>? displayName,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? projectionUpdatedAt,
  }) {
    return RawValuesInsertable({
      if (projectId != null) 'project_id': projectId,
      if (path != null) 'path': path,
      if (hidden != null) 'hidden': hidden,
      if (baseBranch != null) 'base_branch': baseBranch,
      if (worktreeCounter != null) 'worktree_counter': worktreeCounter,
      if (displayName != null) 'display_name': displayName,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (projectionUpdatedAt != null)
        'projection_updated_at': projectionUpdatedAt,
    });
  }

  ProjectsTableCompanion copyWith({
    Value<String>? projectId,
    Value<String>? path,
    Value<bool>? hidden,
    Value<String?>? baseBranch,
    Value<int>? worktreeCounter,
    Value<String?>? displayName,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? projectionUpdatedAt,
  }) {
    return ProjectsTableCompanion(
      projectId: projectId ?? this.projectId,
      path: path ?? this.path,
      hidden: hidden ?? this.hidden,
      baseBranch: baseBranch ?? this.baseBranch,
      worktreeCounter: worktreeCounter ?? this.worktreeCounter,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      projectionUpdatedAt: projectionUpdatedAt ?? this.projectionUpdatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
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
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (projectionUpdatedAt.present) {
      map['projection_updated_at'] = Variable<int>(projectionUpdatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsTableCompanion(')
          ..write('projectId: $projectId, ')
          ..write('path: $path, ')
          ..write('hidden: $hidden, ')
          ..write('baseBranch: $baseBranch, ')
          ..write('worktreeCounter: $worktreeCounter, ')
          ..write('displayName: $displayName, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('projectionUpdatedAt: $projectionUpdatedAt')
          ..write(')'))
        .toString();
  }
}

mixin $SessionTableTableToColumns implements Insertable<SessionDto> {
  String get sessionId;
  String get backendSessionId;
  String get projectId;
  String? get parentSessionId;
  String get directory;
  String? get worktreePath;
  String? get branchName;
  bool get isDedicated;
  int? get archivedAt;
  String? get baseBranch;
  String? get baseCommit;
  String? get lastAgent;
  AgentModel? get lastAgentModel;
  int get createdAt;
  int get updatedAt;
  int get projectionUpdatedAt;
  int? get lastActivityAt;
  int? get lastSeenAt;
  int? get lastUserMessageAt;

  /// The id of the plugin that owns this session (e.g. "opencode", "codex").
  /// No default — every insert stamps the active plugin's id explicitly; the
  /// v7→v8 migration backfills pre-existing rows itself.
  String get pluginId;

  /// The bridge's last-known title for a derived-plugin session (from a
  /// rename or a title-bearing `session.updated` event). Derived backends
  /// (ACP, codex) don't persist renames, so this stored copy wins over the
  /// backend's enumeration title. Null for native plugins (their backend is
  /// authoritative) and for sessions with no bridge-known title.
  String? get title;
  String? get catalogTitle;
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['backend_session_id'] = Variable<String>(backendSessionId);
    map['project_id'] = Variable<String>(projectId);
    if (!nullToAbsent || parentSessionId != null) {
      map['parent_session_id'] = Variable<String>(parentSessionId);
    }
    map['directory'] = Variable<String>(directory);
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
    if (!nullToAbsent || lastAgent != null) {
      map['last_agent'] = Variable<String>(lastAgent);
    }
    if (!nullToAbsent || lastAgentModel != null) {
      map['last_agent_model'] = Variable<String>(
        $SessionTableTable.$converterlastAgentModeln.toSql(lastAgentModel),
      );
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['projection_updated_at'] = Variable<int>(projectionUpdatedAt);
    if (!nullToAbsent || lastActivityAt != null) {
      map['last_activity_at'] = Variable<int>(lastActivityAt);
    }
    if (!nullToAbsent || lastSeenAt != null) {
      map['last_seen_at'] = Variable<int>(lastSeenAt);
    }
    if (!nullToAbsent || lastUserMessageAt != null) {
      map['last_user_message_at'] = Variable<int>(lastUserMessageAt);
    }
    map['plugin_id'] = Variable<String>(pluginId);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || catalogTitle != null) {
      map['catalog_title'] = Variable<String>(catalogTitle);
    }
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
  static const VerificationMeta _backendSessionIdMeta = const VerificationMeta(
    'backendSessionId',
  );
  @override
  late final GeneratedColumn<String> backendSessionId = GeneratedColumn<String>(
    'backend_session_id',
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
  static const VerificationMeta _parentSessionIdMeta = const VerificationMeta(
    'parentSessionId',
  );
  @override
  late final GeneratedColumn<String> parentSessionId = GeneratedColumn<String>(
    'parent_session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions_table (session_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _directoryMeta = const VerificationMeta(
    'directory',
  );
  @override
  late final GeneratedColumn<String> directory = GeneratedColumn<String>(
    'directory',
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
  static const VerificationMeta _lastAgentMeta = const VerificationMeta(
    'lastAgent',
  );
  @override
  late final GeneratedColumn<String> lastAgent = GeneratedColumn<String>(
    'last_agent',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AgentModel?, String>
  lastAgentModel = GeneratedColumn<String>(
    'last_agent_model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<AgentModel?>($SessionTableTable.$converterlastAgentModeln);
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectionUpdatedAtMeta =
      const VerificationMeta('projectionUpdatedAt');
  @override
  late final GeneratedColumn<int> projectionUpdatedAt = GeneratedColumn<int>(
    'projection_updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastActivityAtMeta = const VerificationMeta(
    'lastActivityAt',
  );
  @override
  late final GeneratedColumn<int> lastActivityAt = GeneratedColumn<int>(
    'last_activity_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<int> lastSeenAt = GeneratedColumn<int>(
    'last_seen_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastUserMessageAtMeta = const VerificationMeta(
    'lastUserMessageAt',
  );
  @override
  late final GeneratedColumn<int> lastUserMessageAt = GeneratedColumn<int>(
    'last_user_message_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pluginIdMeta = const VerificationMeta(
    'pluginId',
  );
  @override
  late final GeneratedColumn<String> pluginId = GeneratedColumn<String>(
    'plugin_id',
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _catalogTitleMeta = const VerificationMeta(
    'catalogTitle',
  );
  @override
  late final GeneratedColumn<String> catalogTitle = GeneratedColumn<String>(
    'catalog_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    backendSessionId,
    projectId,
    parentSessionId,
    directory,
    worktreePath,
    branchName,
    isDedicated,
    archivedAt,
    baseBranch,
    baseCommit,
    lastAgent,
    lastAgentModel,
    createdAt,
    updatedAt,
    projectionUpdatedAt,
    lastActivityAt,
    lastSeenAt,
    lastUserMessageAt,
    pluginId,
    title,
    catalogTitle,
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
    if (data.containsKey('backend_session_id')) {
      context.handle(
        _backendSessionIdMeta,
        backendSessionId.isAcceptableOrUnknown(
          data['backend_session_id']!,
          _backendSessionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_backendSessionIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('parent_session_id')) {
      context.handle(
        _parentSessionIdMeta,
        parentSessionId.isAcceptableOrUnknown(
          data['parent_session_id']!,
          _parentSessionIdMeta,
        ),
      );
    }
    if (data.containsKey('directory')) {
      context.handle(
        _directoryMeta,
        directory.isAcceptableOrUnknown(data['directory']!, _directoryMeta),
      );
    } else if (isInserting) {
      context.missing(_directoryMeta);
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
    if (data.containsKey('last_agent')) {
      context.handle(
        _lastAgentMeta,
        lastAgent.isAcceptableOrUnknown(data['last_agent']!, _lastAgentMeta),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('projection_updated_at')) {
      context.handle(
        _projectionUpdatedAtMeta,
        projectionUpdatedAt.isAcceptableOrUnknown(
          data['projection_updated_at']!,
          _projectionUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_projectionUpdatedAtMeta);
    }
    if (data.containsKey('last_activity_at')) {
      context.handle(
        _lastActivityAtMeta,
        lastActivityAt.isAcceptableOrUnknown(
          data['last_activity_at']!,
          _lastActivityAtMeta,
        ),
      );
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    }
    if (data.containsKey('last_user_message_at')) {
      context.handle(
        _lastUserMessageAtMeta,
        lastUserMessageAt.isAcceptableOrUnknown(
          data['last_user_message_at']!,
          _lastUserMessageAtMeta,
        ),
      );
    }
    if (data.containsKey('plugin_id')) {
      context.handle(
        _pluginIdMeta,
        pluginId.isAcceptableOrUnknown(data['plugin_id']!, _pluginIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pluginIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('catalog_title')) {
      context.handle(
        _catalogTitleMeta,
        catalogTitle.isAcceptableOrUnknown(
          data['catalog_title']!,
          _catalogTitleMeta,
        ),
      );
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
      backendSessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backend_session_id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      parentSessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_session_id'],
      ),
      directory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}directory'],
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
      lastAgent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_agent'],
      ),
      lastAgentModel: $SessionTableTable.$converterlastAgentModeln.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}last_agent_model'],
        ),
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      projectionUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}projection_updated_at'],
      )!,
      lastActivityAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_activity_at'],
      ),
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen_at'],
      ),
      lastUserMessageAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_user_message_at'],
      ),
      pluginId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plugin_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      catalogTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}catalog_title'],
      ),
    );
  }

  @override
  $SessionTableTable createAlias(String alias) {
    return $SessionTableTable(attachedDatabase, alias);
  }

  static TypeConverter<AgentModel, String> $converterlastAgentModel =
      const AgentModelConverter();
  static TypeConverter<AgentModel?, String?> $converterlastAgentModeln =
      NullAwareTypeConverter.wrap($converterlastAgentModel);
  @override
  bool get withoutRowId => true;
}

class SessionTableCompanion extends UpdateCompanion<SessionDto> {
  final Value<String> sessionId;
  final Value<String> backendSessionId;
  final Value<String> projectId;
  final Value<String?> parentSessionId;
  final Value<String> directory;
  final Value<String?> worktreePath;
  final Value<String?> branchName;
  final Value<bool> isDedicated;
  final Value<int?> archivedAt;
  final Value<String?> baseBranch;
  final Value<String?> baseCommit;
  final Value<String?> lastAgent;
  final Value<AgentModel?> lastAgentModel;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> projectionUpdatedAt;
  final Value<int?> lastActivityAt;
  final Value<int?> lastSeenAt;
  final Value<int?> lastUserMessageAt;
  final Value<String> pluginId;
  final Value<String?> title;
  final Value<String?> catalogTitle;
  const SessionTableCompanion({
    this.sessionId = const Value.absent(),
    this.backendSessionId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.parentSessionId = const Value.absent(),
    this.directory = const Value.absent(),
    this.worktreePath = const Value.absent(),
    this.branchName = const Value.absent(),
    this.isDedicated = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.baseBranch = const Value.absent(),
    this.baseCommit = const Value.absent(),
    this.lastAgent = const Value.absent(),
    this.lastAgentModel = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.projectionUpdatedAt = const Value.absent(),
    this.lastActivityAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.lastUserMessageAt = const Value.absent(),
    this.pluginId = const Value.absent(),
    this.title = const Value.absent(),
    this.catalogTitle = const Value.absent(),
  });
  SessionTableCompanion.insert({
    required String sessionId,
    required String backendSessionId,
    required String projectId,
    this.parentSessionId = const Value.absent(),
    required String directory,
    this.worktreePath = const Value.absent(),
    this.branchName = const Value.absent(),
    required bool isDedicated,
    this.archivedAt = const Value.absent(),
    this.baseBranch = const Value.absent(),
    this.baseCommit = const Value.absent(),
    this.lastAgent = const Value.absent(),
    this.lastAgentModel = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    required int projectionUpdatedAt,
    this.lastActivityAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.lastUserMessageAt = const Value.absent(),
    required String pluginId,
    this.title = const Value.absent(),
    this.catalogTitle = const Value.absent(),
  }) : sessionId = Value(sessionId),
       backendSessionId = Value(backendSessionId),
       projectId = Value(projectId),
       directory = Value(directory),
       isDedicated = Value(isDedicated),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       projectionUpdatedAt = Value(projectionUpdatedAt),
       pluginId = Value(pluginId);
  static Insertable<SessionDto> custom({
    Expression<String>? sessionId,
    Expression<String>? backendSessionId,
    Expression<String>? projectId,
    Expression<String>? parentSessionId,
    Expression<String>? directory,
    Expression<String>? worktreePath,
    Expression<String>? branchName,
    Expression<bool>? isDedicated,
    Expression<int>? archivedAt,
    Expression<String>? baseBranch,
    Expression<String>? baseCommit,
    Expression<String>? lastAgent,
    Expression<String>? lastAgentModel,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? projectionUpdatedAt,
    Expression<int>? lastActivityAt,
    Expression<int>? lastSeenAt,
    Expression<int>? lastUserMessageAt,
    Expression<String>? pluginId,
    Expression<String>? title,
    Expression<String>? catalogTitle,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (backendSessionId != null) 'backend_session_id': backendSessionId,
      if (projectId != null) 'project_id': projectId,
      if (parentSessionId != null) 'parent_session_id': parentSessionId,
      if (directory != null) 'directory': directory,
      if (worktreePath != null) 'worktree_path': worktreePath,
      if (branchName != null) 'branch_name': branchName,
      if (isDedicated != null) 'is_dedicated': isDedicated,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (baseBranch != null) 'base_branch': baseBranch,
      if (baseCommit != null) 'base_commit': baseCommit,
      if (lastAgent != null) 'last_agent': lastAgent,
      if (lastAgentModel != null) 'last_agent_model': lastAgentModel,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (projectionUpdatedAt != null)
        'projection_updated_at': projectionUpdatedAt,
      if (lastActivityAt != null) 'last_activity_at': lastActivityAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (lastUserMessageAt != null) 'last_user_message_at': lastUserMessageAt,
      if (pluginId != null) 'plugin_id': pluginId,
      if (title != null) 'title': title,
      if (catalogTitle != null) 'catalog_title': catalogTitle,
    });
  }

  SessionTableCompanion copyWith({
    Value<String>? sessionId,
    Value<String>? backendSessionId,
    Value<String>? projectId,
    Value<String?>? parentSessionId,
    Value<String>? directory,
    Value<String?>? worktreePath,
    Value<String?>? branchName,
    Value<bool>? isDedicated,
    Value<int?>? archivedAt,
    Value<String?>? baseBranch,
    Value<String?>? baseCommit,
    Value<String?>? lastAgent,
    Value<AgentModel?>? lastAgentModel,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? projectionUpdatedAt,
    Value<int?>? lastActivityAt,
    Value<int?>? lastSeenAt,
    Value<int?>? lastUserMessageAt,
    Value<String>? pluginId,
    Value<String?>? title,
    Value<String?>? catalogTitle,
  }) {
    return SessionTableCompanion(
      sessionId: sessionId ?? this.sessionId,
      backendSessionId: backendSessionId ?? this.backendSessionId,
      projectId: projectId ?? this.projectId,
      parentSessionId: parentSessionId ?? this.parentSessionId,
      directory: directory ?? this.directory,
      worktreePath: worktreePath ?? this.worktreePath,
      branchName: branchName ?? this.branchName,
      isDedicated: isDedicated ?? this.isDedicated,
      archivedAt: archivedAt ?? this.archivedAt,
      baseBranch: baseBranch ?? this.baseBranch,
      baseCommit: baseCommit ?? this.baseCommit,
      lastAgent: lastAgent ?? this.lastAgent,
      lastAgentModel: lastAgentModel ?? this.lastAgentModel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      projectionUpdatedAt: projectionUpdatedAt ?? this.projectionUpdatedAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lastUserMessageAt: lastUserMessageAt ?? this.lastUserMessageAt,
      pluginId: pluginId ?? this.pluginId,
      title: title ?? this.title,
      catalogTitle: catalogTitle ?? this.catalogTitle,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (backendSessionId.present) {
      map['backend_session_id'] = Variable<String>(backendSessionId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (parentSessionId.present) {
      map['parent_session_id'] = Variable<String>(parentSessionId.value);
    }
    if (directory.present) {
      map['directory'] = Variable<String>(directory.value);
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
    if (lastAgent.present) {
      map['last_agent'] = Variable<String>(lastAgent.value);
    }
    if (lastAgentModel.present) {
      map['last_agent_model'] = Variable<String>(
        $SessionTableTable.$converterlastAgentModeln.toSql(
          lastAgentModel.value,
        ),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (projectionUpdatedAt.present) {
      map['projection_updated_at'] = Variable<int>(projectionUpdatedAt.value);
    }
    if (lastActivityAt.present) {
      map['last_activity_at'] = Variable<int>(lastActivityAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<int>(lastSeenAt.value);
    }
    if (lastUserMessageAt.present) {
      map['last_user_message_at'] = Variable<int>(lastUserMessageAt.value);
    }
    if (pluginId.present) {
      map['plugin_id'] = Variable<String>(pluginId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (catalogTitle.present) {
      map['catalog_title'] = Variable<String>(catalogTitle.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionTableCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('backendSessionId: $backendSessionId, ')
          ..write('projectId: $projectId, ')
          ..write('parentSessionId: $parentSessionId, ')
          ..write('directory: $directory, ')
          ..write('worktreePath: $worktreePath, ')
          ..write('branchName: $branchName, ')
          ..write('isDedicated: $isDedicated, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('baseBranch: $baseBranch, ')
          ..write('baseCommit: $baseCommit, ')
          ..write('lastAgent: $lastAgent, ')
          ..write('lastAgentModel: $lastAgentModel, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('projectionUpdatedAt: $projectionUpdatedAt, ')
          ..write('lastActivityAt: $lastActivityAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('lastUserMessageAt: $lastUserMessageAt, ')
          ..write('pluginId: $pluginId, ')
          ..write('title: $title, ')
          ..write('catalogTitle: $catalogTitle')
          ..write(')'))
        .toString();
  }
}

mixin $DeletedSessionsTableTableToColumns
    implements Insertable<DeletedSessionDto> {
  /// Current owner of this durable local entity. Local mode has one owner;
  /// carrying it in the key keeps future identity scoping possible.
  String get ownerIdentity;
  String get backendSessionId;

  /// The id of the plugin that owned the session. Scoping keeps one plugin's
  /// tombstones from ever touching another plugin's sessions.
  String get pluginId;
  int get deletedAt;
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_identity'] = Variable<String>(ownerIdentity);
    map['backend_session_id'] = Variable<String>(backendSessionId);
    map['plugin_id'] = Variable<String>(pluginId);
    map['deleted_at'] = Variable<int>(deletedAt);
    return map;
  }
}

class $DeletedSessionsTableTable extends DeletedSessionsTable
    with TableInfo<$DeletedSessionsTableTable, DeletedSessionDto> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeletedSessionsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerIdentityMeta = const VerificationMeta(
    'ownerIdentity',
  );
  @override
  late final GeneratedColumn<String> ownerIdentity = GeneratedColumn<String>(
    'owner_identity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant("local"),
  );
  static const VerificationMeta _backendSessionIdMeta = const VerificationMeta(
    'backendSessionId',
  );
  @override
  late final GeneratedColumn<String> backendSessionId = GeneratedColumn<String>(
    'backend_session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pluginIdMeta = const VerificationMeta(
    'pluginId',
  );
  @override
  late final GeneratedColumn<String> pluginId = GeneratedColumn<String>(
    'plugin_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerIdentity,
    backendSessionId,
    pluginId,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deleted_sessions_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeletedSessionDto> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_identity')) {
      context.handle(
        _ownerIdentityMeta,
        ownerIdentity.isAcceptableOrUnknown(
          data['owner_identity']!,
          _ownerIdentityMeta,
        ),
      );
    }
    if (data.containsKey('backend_session_id')) {
      context.handle(
        _backendSessionIdMeta,
        backendSessionId.isAcceptableOrUnknown(
          data['backend_session_id']!,
          _backendSessionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_backendSessionIdMeta);
    }
    if (data.containsKey('plugin_id')) {
      context.handle(
        _pluginIdMeta,
        pluginId.isAcceptableOrUnknown(data['plugin_id']!, _pluginIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pluginIdMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_deletedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    ownerIdentity,
    pluginId,
    backendSessionId,
  };
  @override
  DeletedSessionDto map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeletedSessionDto(
      ownerIdentity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_identity'],
      )!,
      backendSessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backend_session_id'],
      )!,
      pluginId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plugin_id'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      )!,
    );
  }

  @override
  $DeletedSessionsTableTable createAlias(String alias) {
    return $DeletedSessionsTableTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class DeletedSessionsTableCompanion extends UpdateCompanion<DeletedSessionDto> {
  final Value<String> ownerIdentity;
  final Value<String> backendSessionId;
  final Value<String> pluginId;
  final Value<int> deletedAt;
  const DeletedSessionsTableCompanion({
    this.ownerIdentity = const Value.absent(),
    this.backendSessionId = const Value.absent(),
    this.pluginId = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  DeletedSessionsTableCompanion.insert({
    this.ownerIdentity = const Value.absent(),
    required String backendSessionId,
    required String pluginId,
    required int deletedAt,
  }) : backendSessionId = Value(backendSessionId),
       pluginId = Value(pluginId),
       deletedAt = Value(deletedAt);
  static Insertable<DeletedSessionDto> custom({
    Expression<String>? ownerIdentity,
    Expression<String>? backendSessionId,
    Expression<String>? pluginId,
    Expression<int>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (ownerIdentity != null) 'owner_identity': ownerIdentity,
      if (backendSessionId != null) 'backend_session_id': backendSessionId,
      if (pluginId != null) 'plugin_id': pluginId,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  DeletedSessionsTableCompanion copyWith({
    Value<String>? ownerIdentity,
    Value<String>? backendSessionId,
    Value<String>? pluginId,
    Value<int>? deletedAt,
  }) {
    return DeletedSessionsTableCompanion(
      ownerIdentity: ownerIdentity ?? this.ownerIdentity,
      backendSessionId: backendSessionId ?? this.backendSessionId,
      pluginId: pluginId ?? this.pluginId,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerIdentity.present) {
      map['owner_identity'] = Variable<String>(ownerIdentity.value);
    }
    if (backendSessionId.present) {
      map['backend_session_id'] = Variable<String>(backendSessionId.value);
    }
    if (pluginId.present) {
      map['plugin_id'] = Variable<String>(pluginId.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeletedSessionsTableCompanion(')
          ..write('ownerIdentity: $ownerIdentity, ')
          ..write('backendSessionId: $backendSessionId, ')
          ..write('pluginId: $pluginId, ')
          ..write('deletedAt: $deletedAt')
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

mixin $CatalogHydrationsTableTableToColumns
    implements Insertable<CatalogHydrationDto> {
  String get pluginId;
  int get projectionVersion;
  int get completedAt;
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['plugin_id'] = Variable<String>(pluginId);
    map['projection_version'] = Variable<int>(projectionVersion);
    map['completed_at'] = Variable<int>(completedAt);
    return map;
  }
}

class $CatalogHydrationsTableTable extends CatalogHydrationsTable
    with TableInfo<$CatalogHydrationsTableTable, CatalogHydrationDto> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogHydrationsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pluginIdMeta = const VerificationMeta(
    'pluginId',
  );
  @override
  late final GeneratedColumn<String> pluginId = GeneratedColumn<String>(
    'plugin_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectionVersionMeta = const VerificationMeta(
    'projectionVersion',
  );
  @override
  late final GeneratedColumn<int> projectionVersion = GeneratedColumn<int>(
    'projection_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    pluginId,
    projectionVersion,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalog_hydrations_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatalogHydrationDto> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('plugin_id')) {
      context.handle(
        _pluginIdMeta,
        pluginId.isAcceptableOrUnknown(data['plugin_id']!, _pluginIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pluginIdMeta);
    }
    if (data.containsKey('projection_version')) {
      context.handle(
        _projectionVersionMeta,
        projectionVersion.isAcceptableOrUnknown(
          data['projection_version']!,
          _projectionVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_projectionVersionMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pluginId, projectionVersion};
  @override
  CatalogHydrationDto map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogHydrationDto(
      pluginId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plugin_id'],
      )!,
      projectionVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}projection_version'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      )!,
    );
  }

  @override
  $CatalogHydrationsTableTable createAlias(String alias) {
    return $CatalogHydrationsTableTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class CatalogHydrationsTableCompanion
    extends UpdateCompanion<CatalogHydrationDto> {
  final Value<String> pluginId;
  final Value<int> projectionVersion;
  final Value<int> completedAt;
  const CatalogHydrationsTableCompanion({
    this.pluginId = const Value.absent(),
    this.projectionVersion = const Value.absent(),
    this.completedAt = const Value.absent(),
  });
  CatalogHydrationsTableCompanion.insert({
    required String pluginId,
    required int projectionVersion,
    required int completedAt,
  }) : pluginId = Value(pluginId),
       projectionVersion = Value(projectionVersion),
       completedAt = Value(completedAt);
  static Insertable<CatalogHydrationDto> custom({
    Expression<String>? pluginId,
    Expression<int>? projectionVersion,
    Expression<int>? completedAt,
  }) {
    return RawValuesInsertable({
      if (pluginId != null) 'plugin_id': pluginId,
      if (projectionVersion != null) 'projection_version': projectionVersion,
      if (completedAt != null) 'completed_at': completedAt,
    });
  }

  CatalogHydrationsTableCompanion copyWith({
    Value<String>? pluginId,
    Value<int>? projectionVersion,
    Value<int>? completedAt,
  }) {
    return CatalogHydrationsTableCompanion(
      pluginId: pluginId ?? this.pluginId,
      projectionVersion: projectionVersion ?? this.projectionVersion,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pluginId.present) {
      map['plugin_id'] = Variable<String>(pluginId.value);
    }
    if (projectionVersion.present) {
      map['projection_version'] = Variable<int>(projectionVersion.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogHydrationsTableCompanion(')
          ..write('pluginId: $pluginId, ')
          ..write('projectionVersion: $projectionVersion, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProjectsTableTable projectsTable = $ProjectsTableTable(this);
  late final $SessionTableTable sessionTable = $SessionTableTable(this);
  late final $DeletedSessionsTableTable deletedSessionsTable =
      $DeletedSessionsTableTable(this);
  late final $PullRequestsTableTable pullRequestsTable =
      $PullRequestsTableTable(this);
  late final $CatalogHydrationsTableTable catalogHydrationsTable =
      $CatalogHydrationsTableTable(this);
  late final Index idxProjectsPath = Index(
    'idx_projects_path',
    'CREATE INDEX idx_projects_path ON projects_table (path)',
  );
  late final Index idxProjectsUpdated = Index(
    'idx_projects_updated',
    'CREATE INDEX idx_projects_updated ON projects_table (updated_at DESC, project_id DESC)',
  );
  late final Index idxSessionsPluginBackend = Index(
    'idx_sessions_plugin_backend',
    'CREATE UNIQUE INDEX idx_sessions_plugin_backend ON sessions_table (plugin_id, backend_session_id)',
  );
  late final Index idxSessionsRoots = Index(
    'idx_sessions_roots',
    'CREATE INDEX idx_sessions_roots ON sessions_table (project_id, parent_session_id, updated_at, session_id)',
  );
  late final Index idxSessionsChildren = Index(
    'idx_sessions_children',
    'CREATE INDEX idx_sessions_children ON sessions_table (parent_session_id, updated_at, session_id)',
  );
  late final Index idxSessionsArchive = Index(
    'idx_sessions_archive',
    'CREATE INDEX idx_sessions_archive ON sessions_table (updated_at DESC, session_id DESC) WHERE archived_at IS NOT NULL',
  );
  late final ProjectsDao projectsDao = ProjectsDao(this as AppDatabase);
  late final SessionDao sessionDao = SessionDao(this as AppDatabase);
  late final PullRequestDao pullRequestDao = PullRequestDao(
    this as AppDatabase,
  );
  late final CatalogHydrationsDao catalogHydrationsDao = CatalogHydrationsDao(
    this as AppDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    projectsTable,
    sessionTable,
    deletedSessionsTable,
    pullRequestsTable,
    catalogHydrationsTable,
    idxProjectsPath,
    idxProjectsUpdated,
    idxSessionsPluginBackend,
    idxSessionsRoots,
    idxSessionsChildren,
    idxSessionsArchive,
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
        'sessions_table',
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
      required String path,
      Value<bool> hidden,
      Value<String?> baseBranch,
      Value<int> worktreeCounter,
      Value<String?> displayName,
      Value<int> createdAt,
      Value<int> updatedAt,
      required int projectionUpdatedAt,
    });
typedef $$ProjectsTableTableUpdateCompanionBuilder =
    ProjectsTableCompanion Function({
      Value<String> projectId,
      Value<String> path,
      Value<bool> hidden,
      Value<String?> baseBranch,
      Value<int> worktreeCounter,
      Value<String?> displayName,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> projectionUpdatedAt,
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
    aliasName: 'projects_table__project_id__sessions_table__project_id',
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
        aliasName:
            'projects_table__project_id__pull_requests_table__project_id',
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

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
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

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get projectionUpdatedAt => $composableBuilder(
    column: $table.projectionUpdatedAt,
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

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
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

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get projectionUpdatedAt => $composableBuilder(
    column: $table.projectionUpdatedAt,
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

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

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

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get projectionUpdatedAt => $composableBuilder(
    column: $table.projectionUpdatedAt,
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
                Value<String> path = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<String?> baseBranch = const Value.absent(),
                Value<int> worktreeCounter = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> projectionUpdatedAt = const Value.absent(),
              }) => ProjectsTableCompanion(
                projectId: projectId,
                path: path,
                hidden: hidden,
                baseBranch: baseBranch,
                worktreeCounter: worktreeCounter,
                displayName: displayName,
                createdAt: createdAt,
                updatedAt: updatedAt,
                projectionUpdatedAt: projectionUpdatedAt,
              ),
          createCompanionCallback:
              ({
                required String projectId,
                required String path,
                Value<bool> hidden = const Value.absent(),
                Value<String?> baseBranch = const Value.absent(),
                Value<int> worktreeCounter = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                required int projectionUpdatedAt,
              }) => ProjectsTableCompanion.insert(
                projectId: projectId,
                path: path,
                hidden: hidden,
                baseBranch: baseBranch,
                worktreeCounter: worktreeCounter,
                displayName: displayName,
                createdAt: createdAt,
                updatedAt: updatedAt,
                projectionUpdatedAt: projectionUpdatedAt,
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
      required String backendSessionId,
      required String projectId,
      Value<String?> parentSessionId,
      required String directory,
      Value<String?> worktreePath,
      Value<String?> branchName,
      required bool isDedicated,
      Value<int?> archivedAt,
      Value<String?> baseBranch,
      Value<String?> baseCommit,
      Value<String?> lastAgent,
      Value<AgentModel?> lastAgentModel,
      required int createdAt,
      required int updatedAt,
      required int projectionUpdatedAt,
      Value<int?> lastActivityAt,
      Value<int?> lastSeenAt,
      Value<int?> lastUserMessageAt,
      required String pluginId,
      Value<String?> title,
      Value<String?> catalogTitle,
    });
typedef $$SessionTableTableUpdateCompanionBuilder =
    SessionTableCompanion Function({
      Value<String> sessionId,
      Value<String> backendSessionId,
      Value<String> projectId,
      Value<String?> parentSessionId,
      Value<String> directory,
      Value<String?> worktreePath,
      Value<String?> branchName,
      Value<bool> isDedicated,
      Value<int?> archivedAt,
      Value<String?> baseBranch,
      Value<String?> baseCommit,
      Value<String?> lastAgent,
      Value<AgentModel?> lastAgentModel,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> projectionUpdatedAt,
      Value<int?> lastActivityAt,
      Value<int?> lastSeenAt,
      Value<int?> lastUserMessageAt,
      Value<String> pluginId,
      Value<String?> title,
      Value<String?> catalogTitle,
    });

final class $$SessionTableTableReferences
    extends BaseReferences<_$AppDatabase, $SessionTableTable, SessionDto> {
  $$SessionTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTableTable _projectIdTable(_$AppDatabase db) => db
      .projectsTable
      .createAlias('sessions_table__project_id__projects_table__project_id');

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

  static $SessionTableTable _parentSessionIdTable(_$AppDatabase db) =>
      db.sessionTable.createAlias(
        'sessions_table__parent_session_id__sessions_table__session_id',
      );

  $$SessionTableTableProcessedTableManager? get parentSessionId {
    final $_column = $_itemColumn<String>('parent_session_id');
    if ($_column == null) return null;
    final manager = $$SessionTableTableTableManager(
      $_db,
      $_db.sessionTable,
    ).filter((f) => f.sessionId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentSessionIdTable($_db));
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

  ColumnFilters<String> get backendSessionId => $composableBuilder(
    column: $table.backendSessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get directory => $composableBuilder(
    column: $table.directory,
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

  ColumnFilters<String> get lastAgent => $composableBuilder(
    column: $table.lastAgent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AgentModel?, AgentModel, String>
  get lastAgentModel => $composableBuilder(
    column: $table.lastAgentModel,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get projectionUpdatedAt => $composableBuilder(
    column: $table.projectionUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastActivityAt => $composableBuilder(
    column: $table.lastActivityAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastUserMessageAt => $composableBuilder(
    column: $table.lastUserMessageAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pluginId => $composableBuilder(
    column: $table.pluginId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get catalogTitle => $composableBuilder(
    column: $table.catalogTitle,
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

  $$SessionTableTableFilterComposer get parentSessionId {
    final $$SessionTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentSessionId,
      referencedTable: $db.sessionTable,
      getReferencedColumn: (t) => t.sessionId,
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

  ColumnOrderings<String> get backendSessionId => $composableBuilder(
    column: $table.backendSessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get directory => $composableBuilder(
    column: $table.directory,
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

  ColumnOrderings<String> get lastAgent => $composableBuilder(
    column: $table.lastAgent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastAgentModel => $composableBuilder(
    column: $table.lastAgentModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get projectionUpdatedAt => $composableBuilder(
    column: $table.projectionUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastActivityAt => $composableBuilder(
    column: $table.lastActivityAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastUserMessageAt => $composableBuilder(
    column: $table.lastUserMessageAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pluginId => $composableBuilder(
    column: $table.pluginId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get catalogTitle => $composableBuilder(
    column: $table.catalogTitle,
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

  $$SessionTableTableOrderingComposer get parentSessionId {
    final $$SessionTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentSessionId,
      referencedTable: $db.sessionTable,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionTableTableOrderingComposer(
            $db: $db,
            $table: $db.sessionTable,
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

  GeneratedColumn<String> get backendSessionId => $composableBuilder(
    column: $table.backendSessionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get directory =>
      $composableBuilder(column: $table.directory, builder: (column) => column);

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

  GeneratedColumn<String> get lastAgent =>
      $composableBuilder(column: $table.lastAgent, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AgentModel?, String> get lastAgentModel =>
      $composableBuilder(
        column: $table.lastAgentModel,
        builder: (column) => column,
      );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get projectionUpdatedAt => $composableBuilder(
    column: $table.projectionUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastActivityAt => $composableBuilder(
    column: $table.lastActivityAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastUserMessageAt => $composableBuilder(
    column: $table.lastUserMessageAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pluginId =>
      $composableBuilder(column: $table.pluginId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get catalogTitle => $composableBuilder(
    column: $table.catalogTitle,
    builder: (column) => column,
  );

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

  $$SessionTableTableAnnotationComposer get parentSessionId {
    final $$SessionTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentSessionId,
      referencedTable: $db.sessionTable,
      getReferencedColumn: (t) => t.sessionId,
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
          PrefetchHooks Function({bool projectId, bool parentSessionId})
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
                Value<String> backendSessionId = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String?> parentSessionId = const Value.absent(),
                Value<String> directory = const Value.absent(),
                Value<String?> worktreePath = const Value.absent(),
                Value<String?> branchName = const Value.absent(),
                Value<bool> isDedicated = const Value.absent(),
                Value<int?> archivedAt = const Value.absent(),
                Value<String?> baseBranch = const Value.absent(),
                Value<String?> baseCommit = const Value.absent(),
                Value<String?> lastAgent = const Value.absent(),
                Value<AgentModel?> lastAgentModel = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> projectionUpdatedAt = const Value.absent(),
                Value<int?> lastActivityAt = const Value.absent(),
                Value<int?> lastSeenAt = const Value.absent(),
                Value<int?> lastUserMessageAt = const Value.absent(),
                Value<String> pluginId = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> catalogTitle = const Value.absent(),
              }) => SessionTableCompanion(
                sessionId: sessionId,
                backendSessionId: backendSessionId,
                projectId: projectId,
                parentSessionId: parentSessionId,
                directory: directory,
                worktreePath: worktreePath,
                branchName: branchName,
                isDedicated: isDedicated,
                archivedAt: archivedAt,
                baseBranch: baseBranch,
                baseCommit: baseCommit,
                lastAgent: lastAgent,
                lastAgentModel: lastAgentModel,
                createdAt: createdAt,
                updatedAt: updatedAt,
                projectionUpdatedAt: projectionUpdatedAt,
                lastActivityAt: lastActivityAt,
                lastSeenAt: lastSeenAt,
                lastUserMessageAt: lastUserMessageAt,
                pluginId: pluginId,
                title: title,
                catalogTitle: catalogTitle,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required String backendSessionId,
                required String projectId,
                Value<String?> parentSessionId = const Value.absent(),
                required String directory,
                Value<String?> worktreePath = const Value.absent(),
                Value<String?> branchName = const Value.absent(),
                required bool isDedicated,
                Value<int?> archivedAt = const Value.absent(),
                Value<String?> baseBranch = const Value.absent(),
                Value<String?> baseCommit = const Value.absent(),
                Value<String?> lastAgent = const Value.absent(),
                Value<AgentModel?> lastAgentModel = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                required int projectionUpdatedAt,
                Value<int?> lastActivityAt = const Value.absent(),
                Value<int?> lastSeenAt = const Value.absent(),
                Value<int?> lastUserMessageAt = const Value.absent(),
                required String pluginId,
                Value<String?> title = const Value.absent(),
                Value<String?> catalogTitle = const Value.absent(),
              }) => SessionTableCompanion.insert(
                sessionId: sessionId,
                backendSessionId: backendSessionId,
                projectId: projectId,
                parentSessionId: parentSessionId,
                directory: directory,
                worktreePath: worktreePath,
                branchName: branchName,
                isDedicated: isDedicated,
                archivedAt: archivedAt,
                baseBranch: baseBranch,
                baseCommit: baseCommit,
                lastAgent: lastAgent,
                lastAgentModel: lastAgentModel,
                createdAt: createdAt,
                updatedAt: updatedAt,
                projectionUpdatedAt: projectionUpdatedAt,
                lastActivityAt: lastActivityAt,
                lastSeenAt: lastSeenAt,
                lastUserMessageAt: lastUserMessageAt,
                pluginId: pluginId,
                title: title,
                catalogTitle: catalogTitle,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SessionTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({projectId = false, parentSessionId = false}) {
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
                                        $$SessionTableTableReferences
                                            ._projectIdTable(db),
                                    referencedColumn:
                                        $$SessionTableTableReferences
                                            ._projectIdTable(db)
                                            .projectId,
                                  )
                                  as T;
                        }
                        if (parentSessionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.parentSessionId,
                                    referencedTable:
                                        $$SessionTableTableReferences
                                            ._parentSessionIdTable(db),
                                    referencedColumn:
                                        $$SessionTableTableReferences
                                            ._parentSessionIdTable(db)
                                            .sessionId,
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
      PrefetchHooks Function({bool projectId, bool parentSessionId})
    >;
typedef $$DeletedSessionsTableTableCreateCompanionBuilder =
    DeletedSessionsTableCompanion Function({
      Value<String> ownerIdentity,
      required String backendSessionId,
      required String pluginId,
      required int deletedAt,
    });
typedef $$DeletedSessionsTableTableUpdateCompanionBuilder =
    DeletedSessionsTableCompanion Function({
      Value<String> ownerIdentity,
      Value<String> backendSessionId,
      Value<String> pluginId,
      Value<int> deletedAt,
    });

class $$DeletedSessionsTableTableFilterComposer
    extends Composer<_$AppDatabase, $DeletedSessionsTableTable> {
  $$DeletedSessionsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerIdentity => $composableBuilder(
    column: $table.ownerIdentity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backendSessionId => $composableBuilder(
    column: $table.backendSessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pluginId => $composableBuilder(
    column: $table.pluginId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeletedSessionsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $DeletedSessionsTableTable> {
  $$DeletedSessionsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerIdentity => $composableBuilder(
    column: $table.ownerIdentity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backendSessionId => $composableBuilder(
    column: $table.backendSessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pluginId => $composableBuilder(
    column: $table.pluginId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeletedSessionsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeletedSessionsTableTable> {
  $$DeletedSessionsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerIdentity => $composableBuilder(
    column: $table.ownerIdentity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get backendSessionId => $composableBuilder(
    column: $table.backendSessionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pluginId =>
      $composableBuilder(column: $table.pluginId, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$DeletedSessionsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeletedSessionsTableTable,
          DeletedSessionDto,
          $$DeletedSessionsTableTableFilterComposer,
          $$DeletedSessionsTableTableOrderingComposer,
          $$DeletedSessionsTableTableAnnotationComposer,
          $$DeletedSessionsTableTableCreateCompanionBuilder,
          $$DeletedSessionsTableTableUpdateCompanionBuilder,
          (
            DeletedSessionDto,
            BaseReferences<
              _$AppDatabase,
              $DeletedSessionsTableTable,
              DeletedSessionDto
            >,
          ),
          DeletedSessionDto,
          PrefetchHooks Function()
        > {
  $$DeletedSessionsTableTableTableManager(
    _$AppDatabase db,
    $DeletedSessionsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeletedSessionsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeletedSessionsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DeletedSessionsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> ownerIdentity = const Value.absent(),
                Value<String> backendSessionId = const Value.absent(),
                Value<String> pluginId = const Value.absent(),
                Value<int> deletedAt = const Value.absent(),
              }) => DeletedSessionsTableCompanion(
                ownerIdentity: ownerIdentity,
                backendSessionId: backendSessionId,
                pluginId: pluginId,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<String> ownerIdentity = const Value.absent(),
                required String backendSessionId,
                required String pluginId,
                required int deletedAt,
              }) => DeletedSessionsTableCompanion.insert(
                ownerIdentity: ownerIdentity,
                backendSessionId: backendSessionId,
                pluginId: pluginId,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeletedSessionsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeletedSessionsTableTable,
      DeletedSessionDto,
      $$DeletedSessionsTableTableFilterComposer,
      $$DeletedSessionsTableTableOrderingComposer,
      $$DeletedSessionsTableTableAnnotationComposer,
      $$DeletedSessionsTableTableCreateCompanionBuilder,
      $$DeletedSessionsTableTableUpdateCompanionBuilder,
      (
        DeletedSessionDto,
        BaseReferences<
          _$AppDatabase,
          $DeletedSessionsTableTable,
          DeletedSessionDto
        >,
      ),
      DeletedSessionDto,
      PrefetchHooks Function()
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
        'pull_requests_table__project_id__projects_table__project_id',
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
typedef $$CatalogHydrationsTableTableCreateCompanionBuilder =
    CatalogHydrationsTableCompanion Function({
      required String pluginId,
      required int projectionVersion,
      required int completedAt,
    });
typedef $$CatalogHydrationsTableTableUpdateCompanionBuilder =
    CatalogHydrationsTableCompanion Function({
      Value<String> pluginId,
      Value<int> projectionVersion,
      Value<int> completedAt,
    });

class $$CatalogHydrationsTableTableFilterComposer
    extends Composer<_$AppDatabase, $CatalogHydrationsTableTable> {
  $$CatalogHydrationsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get pluginId => $composableBuilder(
    column: $table.pluginId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get projectionVersion => $composableBuilder(
    column: $table.projectionVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CatalogHydrationsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $CatalogHydrationsTableTable> {
  $$CatalogHydrationsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get pluginId => $composableBuilder(
    column: $table.pluginId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get projectionVersion => $composableBuilder(
    column: $table.projectionVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatalogHydrationsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $CatalogHydrationsTableTable> {
  $$CatalogHydrationsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get pluginId =>
      $composableBuilder(column: $table.pluginId, builder: (column) => column);

  GeneratedColumn<int> get projectionVersion => $composableBuilder(
    column: $table.projectionVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$CatalogHydrationsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CatalogHydrationsTableTable,
          CatalogHydrationDto,
          $$CatalogHydrationsTableTableFilterComposer,
          $$CatalogHydrationsTableTableOrderingComposer,
          $$CatalogHydrationsTableTableAnnotationComposer,
          $$CatalogHydrationsTableTableCreateCompanionBuilder,
          $$CatalogHydrationsTableTableUpdateCompanionBuilder,
          (
            CatalogHydrationDto,
            BaseReferences<
              _$AppDatabase,
              $CatalogHydrationsTableTable,
              CatalogHydrationDto
            >,
          ),
          CatalogHydrationDto,
          PrefetchHooks Function()
        > {
  $$CatalogHydrationsTableTableTableManager(
    _$AppDatabase db,
    $CatalogHydrationsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogHydrationsTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CatalogHydrationsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CatalogHydrationsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> pluginId = const Value.absent(),
                Value<int> projectionVersion = const Value.absent(),
                Value<int> completedAt = const Value.absent(),
              }) => CatalogHydrationsTableCompanion(
                pluginId: pluginId,
                projectionVersion: projectionVersion,
                completedAt: completedAt,
              ),
          createCompanionCallback:
              ({
                required String pluginId,
                required int projectionVersion,
                required int completedAt,
              }) => CatalogHydrationsTableCompanion.insert(
                pluginId: pluginId,
                projectionVersion: projectionVersion,
                completedAt: completedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CatalogHydrationsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CatalogHydrationsTableTable,
      CatalogHydrationDto,
      $$CatalogHydrationsTableTableFilterComposer,
      $$CatalogHydrationsTableTableOrderingComposer,
      $$CatalogHydrationsTableTableAnnotationComposer,
      $$CatalogHydrationsTableTableCreateCompanionBuilder,
      $$CatalogHydrationsTableTableUpdateCompanionBuilder,
      (
        CatalogHydrationDto,
        BaseReferences<
          _$AppDatabase,
          $CatalogHydrationsTableTable,
          CatalogHydrationDto
        >,
      ),
      CatalogHydrationDto,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProjectsTableTableTableManager get projectsTable =>
      $$ProjectsTableTableTableManager(_db, _db.projectsTable);
  $$SessionTableTableTableManager get sessionTable =>
      $$SessionTableTableTableManager(_db, _db.sessionTable);
  $$DeletedSessionsTableTableTableManager get deletedSessionsTable =>
      $$DeletedSessionsTableTableTableManager(_db, _db.deletedSessionsTable);
  $$PullRequestsTableTableTableManager get pullRequestsTable =>
      $$PullRequestsTableTableTableManager(_db, _db.pullRequestsTable);
  $$CatalogHydrationsTableTableTableManager get catalogHydrationsTable =>
      $$CatalogHydrationsTableTableTableManager(
        _db,
        _db.catalogHydrationsTable,
      );
}
