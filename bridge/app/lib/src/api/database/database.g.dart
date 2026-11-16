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

  /// Bridge-owned display-name override for a renamed aggregate project. Null
  /// means fall back to the directory basename.
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
  final Value<String?> displayName;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> projectionUpdatedAt;
  const ProjectsTableCompanion({
    this.projectId = const Value.absent(),
    this.path = const Value.absent(),
    this.hidden = const Value.absent(),
    this.baseBranch = const Value.absent(),
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
          ..write('displayName: $displayName, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('projectionUpdatedAt: $projectionUpdatedAt')
          ..write(')'))
        .toString();
  }
}

mixin $ScheduledTasksTableTableToColumns
    implements Insertable<ScheduledTaskDto> {
  String get id;
  String get name;
  String get promptJson;
  String get projectId;
  String get pluginId;
  String? get agent;
  String? get modelJson;
  String? get variant;
  bool get fastMode;
  bool get dedicatedWorktree;
  String get scheduleJson;
  String get timeZone;
  TaskMissedRunPolicy get missedRunPolicy;
  ScheduledTaskRunModeKind get runMode;
  bool get autoCompact;
  TaskApprovalMode get approvalMode;
  bool get enabled;

  /// UTC milliseconds of the next run. Null while paused or done.
  int? get nextDueAt;

  /// The session a same-session task continues. Null until its first run, and
  /// again once that session is deleted or an edit moves the task elsewhere.
  String? get targetSessionId;

  /// When a one-off task ran. A done task leaves the list but keeps its row,
  /// so its session keeps the task's mark.
  int? get completedAt;
  int get createdAt;
  int get updatedAt;
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['prompt_json'] = Variable<String>(promptJson);
    map['project_id'] = Variable<String>(projectId);
    map['plugin_id'] = Variable<String>(pluginId);
    if (!nullToAbsent || agent != null) {
      map['agent'] = Variable<String>(agent);
    }
    if (!nullToAbsent || modelJson != null) {
      map['model_json'] = Variable<String>(modelJson);
    }
    if (!nullToAbsent || variant != null) {
      map['variant'] = Variable<String>(variant);
    }
    map['fast_mode'] = Variable<bool>(fastMode);
    map['dedicated_worktree'] = Variable<bool>(dedicatedWorktree);
    map['schedule_json'] = Variable<String>(scheduleJson);
    map['time_zone'] = Variable<String>(timeZone);
    {
      map['missed_run_policy'] = Variable<String>(
        $ScheduledTasksTableTable.$convertermissedRunPolicy.toSql(
          missedRunPolicy,
        ),
      );
    }
    {
      map['run_mode'] = Variable<String>(
        $ScheduledTasksTableTable.$converterrunMode.toSql(runMode),
      );
    }
    map['auto_compact'] = Variable<bool>(autoCompact);
    {
      map['approval_mode'] = Variable<String>(
        $ScheduledTasksTableTable.$converterapprovalMode.toSql(approvalMode),
      );
    }
    map['enabled'] = Variable<bool>(enabled);
    if (!nullToAbsent || nextDueAt != null) {
      map['next_due_at'] = Variable<int>(nextDueAt);
    }
    if (!nullToAbsent || targetSessionId != null) {
      map['target_session_id'] = Variable<String>(targetSessionId);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }
}

class $ScheduledTasksTableTable extends ScheduledTasksTable
    with TableInfo<$ScheduledTasksTableTable, ScheduledTaskDto> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScheduledTasksTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _promptJsonMeta = const VerificationMeta(
    'promptJson',
  );
  @override
  late final GeneratedColumn<String> promptJson = GeneratedColumn<String>(
    'prompt_json',
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
  static const VerificationMeta _agentMeta = const VerificationMeta('agent');
  @override
  late final GeneratedColumn<String> agent = GeneratedColumn<String>(
    'agent',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelJsonMeta = const VerificationMeta(
    'modelJson',
  );
  @override
  late final GeneratedColumn<String> modelJson = GeneratedColumn<String>(
    'model_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _variantMeta = const VerificationMeta(
    'variant',
  );
  @override
  late final GeneratedColumn<String> variant = GeneratedColumn<String>(
    'variant',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fastModeMeta = const VerificationMeta(
    'fastMode',
  );
  @override
  late final GeneratedColumn<bool> fastMode = GeneratedColumn<bool>(
    'fast_mode',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("fast_mode" IN (0, 1))',
    ),
  );
  static const VerificationMeta _dedicatedWorktreeMeta = const VerificationMeta(
    'dedicatedWorktree',
  );
  @override
  late final GeneratedColumn<bool> dedicatedWorktree = GeneratedColumn<bool>(
    'dedicated_worktree',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dedicated_worktree" IN (0, 1))',
    ),
  );
  static const VerificationMeta _scheduleJsonMeta = const VerificationMeta(
    'scheduleJson',
  );
  @override
  late final GeneratedColumn<String> scheduleJson = GeneratedColumn<String>(
    'schedule_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeZoneMeta = const VerificationMeta(
    'timeZone',
  );
  @override
  late final GeneratedColumn<String> timeZone = GeneratedColumn<String>(
    'time_zone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TaskMissedRunPolicy, String>
  missedRunPolicy =
      GeneratedColumn<String>(
        'missed_run_policy',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TaskMissedRunPolicy>(
        $ScheduledTasksTableTable.$convertermissedRunPolicy,
      );
  @override
  late final GeneratedColumnWithTypeConverter<ScheduledTaskRunModeKind, String>
  runMode =
      GeneratedColumn<String>(
        'run_mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ScheduledTaskRunModeKind>(
        $ScheduledTasksTableTable.$converterrunMode,
      );
  static const VerificationMeta _autoCompactMeta = const VerificationMeta(
    'autoCompact',
  );
  @override
  late final GeneratedColumn<bool> autoCompact = GeneratedColumn<bool>(
    'auto_compact',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_compact" IN (0, 1))',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<TaskApprovalMode, String>
  approvalMode =
      GeneratedColumn<String>(
        'approval_mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TaskApprovalMode>(
        $ScheduledTasksTableTable.$converterapprovalMode,
      );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
  );
  static const VerificationMeta _nextDueAtMeta = const VerificationMeta(
    'nextDueAt',
  );
  @override
  late final GeneratedColumn<int> nextDueAt = GeneratedColumn<int>(
    'next_due_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetSessionIdMeta = const VerificationMeta(
    'targetSessionId',
  );
  @override
  late final GeneratedColumn<String> targetSessionId = GeneratedColumn<String>(
    'target_session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions_table (session_id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    promptJson,
    projectId,
    pluginId,
    agent,
    modelJson,
    variant,
    fastMode,
    dedicatedWorktree,
    scheduleJson,
    timeZone,
    missedRunPolicy,
    runMode,
    autoCompact,
    approvalMode,
    enabled,
    nextDueAt,
    targetSessionId,
    completedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scheduled_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScheduledTaskDto> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('prompt_json')) {
      context.handle(
        _promptJsonMeta,
        promptJson.isAcceptableOrUnknown(data['prompt_json']!, _promptJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_promptJsonMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('plugin_id')) {
      context.handle(
        _pluginIdMeta,
        pluginId.isAcceptableOrUnknown(data['plugin_id']!, _pluginIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pluginIdMeta);
    }
    if (data.containsKey('agent')) {
      context.handle(
        _agentMeta,
        agent.isAcceptableOrUnknown(data['agent']!, _agentMeta),
      );
    }
    if (data.containsKey('model_json')) {
      context.handle(
        _modelJsonMeta,
        modelJson.isAcceptableOrUnknown(data['model_json']!, _modelJsonMeta),
      );
    }
    if (data.containsKey('variant')) {
      context.handle(
        _variantMeta,
        variant.isAcceptableOrUnknown(data['variant']!, _variantMeta),
      );
    }
    if (data.containsKey('fast_mode')) {
      context.handle(
        _fastModeMeta,
        fastMode.isAcceptableOrUnknown(data['fast_mode']!, _fastModeMeta),
      );
    } else if (isInserting) {
      context.missing(_fastModeMeta);
    }
    if (data.containsKey('dedicated_worktree')) {
      context.handle(
        _dedicatedWorktreeMeta,
        dedicatedWorktree.isAcceptableOrUnknown(
          data['dedicated_worktree']!,
          _dedicatedWorktreeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dedicatedWorktreeMeta);
    }
    if (data.containsKey('schedule_json')) {
      context.handle(
        _scheduleJsonMeta,
        scheduleJson.isAcceptableOrUnknown(
          data['schedule_json']!,
          _scheduleJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduleJsonMeta);
    }
    if (data.containsKey('time_zone')) {
      context.handle(
        _timeZoneMeta,
        timeZone.isAcceptableOrUnknown(data['time_zone']!, _timeZoneMeta),
      );
    } else if (isInserting) {
      context.missing(_timeZoneMeta);
    }
    if (data.containsKey('auto_compact')) {
      context.handle(
        _autoCompactMeta,
        autoCompact.isAcceptableOrUnknown(
          data['auto_compact']!,
          _autoCompactMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_autoCompactMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    } else if (isInserting) {
      context.missing(_enabledMeta);
    }
    if (data.containsKey('next_due_at')) {
      context.handle(
        _nextDueAtMeta,
        nextDueAt.isAcceptableOrUnknown(data['next_due_at']!, _nextDueAtMeta),
      );
    }
    if (data.containsKey('target_session_id')) {
      context.handle(
        _targetSessionIdMeta,
        targetSessionId.isAcceptableOrUnknown(
          data['target_session_id']!,
          _targetSessionIdMeta,
        ),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScheduledTaskDto map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduledTaskDto(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      promptJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt_json'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      pluginId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plugin_id'],
      )!,
      agent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent'],
      ),
      modelJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_json'],
      ),
      variant: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variant'],
      ),
      fastMode: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}fast_mode'],
      )!,
      dedicatedWorktree: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dedicated_worktree'],
      )!,
      scheduleJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule_json'],
      )!,
      timeZone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_zone'],
      )!,
      missedRunPolicy: $ScheduledTasksTableTable.$convertermissedRunPolicy
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}missed_run_policy'],
            )!,
          ),
      runMode: $ScheduledTasksTableTable.$converterrunMode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}run_mode'],
        )!,
      ),
      autoCompact: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_compact'],
      )!,
      approvalMode: $ScheduledTasksTableTable.$converterapprovalMode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}approval_mode'],
        )!,
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      nextDueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_due_at'],
      ),
      targetSessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_session_id'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ScheduledTasksTableTable createAlias(String alias) {
    return $ScheduledTasksTableTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TaskMissedRunPolicy, String, String>
  $convertermissedRunPolicy = const EnumNameConverter<TaskMissedRunPolicy>(
    TaskMissedRunPolicy.values,
  );
  static JsonTypeConverter2<ScheduledTaskRunModeKind, String, String>
  $converterrunMode = const EnumNameConverter<ScheduledTaskRunModeKind>(
    ScheduledTaskRunModeKind.values,
  );
  static JsonTypeConverter2<TaskApprovalMode, String, String>
  $converterapprovalMode = const EnumNameConverter<TaskApprovalMode>(
    TaskApprovalMode.values,
  );
  @override
  bool get withoutRowId => true;
}

class ScheduledTaskDto extends DataClass
    with $ScheduledTasksTableTableToColumns {
  @override
  final String id;
  @override
  final String name;
  @override
  final String promptJson;
  @override
  final String projectId;
  @override
  final String pluginId;
  @override
  final String? agent;
  @override
  final String? modelJson;
  @override
  final String? variant;
  @override
  final bool fastMode;
  @override
  final bool dedicatedWorktree;
  @override
  final String scheduleJson;
  @override
  final String timeZone;
  @override
  final TaskMissedRunPolicy missedRunPolicy;
  @override
  final ScheduledTaskRunModeKind runMode;
  @override
  final bool autoCompact;
  @override
  final TaskApprovalMode approvalMode;
  @override
  final bool enabled;

  /// UTC milliseconds of the next run. Null while paused or done.
  @override
  final int? nextDueAt;

  /// The session a same-session task continues. Null until its first run, and
  /// again once that session is deleted or an edit moves the task elsewhere.
  @override
  final String? targetSessionId;

  /// When a one-off task ran. A done task leaves the list but keeps its row,
  /// so its session keeps the task's mark.
  @override
  final int? completedAt;
  @override
  final int createdAt;
  @override
  final int updatedAt;
  const ScheduledTaskDto({
    required this.id,
    required this.name,
    required this.promptJson,
    required this.projectId,
    required this.pluginId,
    this.agent,
    this.modelJson,
    this.variant,
    required this.fastMode,
    required this.dedicatedWorktree,
    required this.scheduleJson,
    required this.timeZone,
    required this.missedRunPolicy,
    required this.runMode,
    required this.autoCompact,
    required this.approvalMode,
    required this.enabled,
    this.nextDueAt,
    this.targetSessionId,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  ScheduledTasksTableCompanion toCompanion(bool nullToAbsent) {
    return ScheduledTasksTableCompanion(
      id: Value(id),
      name: Value(name),
      promptJson: Value(promptJson),
      projectId: Value(projectId),
      pluginId: Value(pluginId),
      agent: agent == null && nullToAbsent
          ? const Value.absent()
          : Value(agent),
      modelJson: modelJson == null && nullToAbsent
          ? const Value.absent()
          : Value(modelJson),
      variant: variant == null && nullToAbsent
          ? const Value.absent()
          : Value(variant),
      fastMode: Value(fastMode),
      dedicatedWorktree: Value(dedicatedWorktree),
      scheduleJson: Value(scheduleJson),
      timeZone: Value(timeZone),
      missedRunPolicy: Value(missedRunPolicy),
      runMode: Value(runMode),
      autoCompact: Value(autoCompact),
      approvalMode: Value(approvalMode),
      enabled: Value(enabled),
      nextDueAt: nextDueAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextDueAt),
      targetSessionId: targetSessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(targetSessionId),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ScheduledTaskDto.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduledTaskDto(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      promptJson: serializer.fromJson<String>(json['promptJson']),
      projectId: serializer.fromJson<String>(json['projectId']),
      pluginId: serializer.fromJson<String>(json['pluginId']),
      agent: serializer.fromJson<String?>(json['agent']),
      modelJson: serializer.fromJson<String?>(json['modelJson']),
      variant: serializer.fromJson<String?>(json['variant']),
      fastMode: serializer.fromJson<bool>(json['fastMode']),
      dedicatedWorktree: serializer.fromJson<bool>(json['dedicatedWorktree']),
      scheduleJson: serializer.fromJson<String>(json['scheduleJson']),
      timeZone: serializer.fromJson<String>(json['timeZone']),
      missedRunPolicy: $ScheduledTasksTableTable.$convertermissedRunPolicy
          .fromJson(serializer.fromJson<String>(json['missedRunPolicy'])),
      runMode: $ScheduledTasksTableTable.$converterrunMode.fromJson(
        serializer.fromJson<String>(json['runMode']),
      ),
      autoCompact: serializer.fromJson<bool>(json['autoCompact']),
      approvalMode: $ScheduledTasksTableTable.$converterapprovalMode.fromJson(
        serializer.fromJson<String>(json['approvalMode']),
      ),
      enabled: serializer.fromJson<bool>(json['enabled']),
      nextDueAt: serializer.fromJson<int?>(json['nextDueAt']),
      targetSessionId: serializer.fromJson<String?>(json['targetSessionId']),
      completedAt: serializer.fromJson<int?>(json['completedAt']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'promptJson': serializer.toJson<String>(promptJson),
      'projectId': serializer.toJson<String>(projectId),
      'pluginId': serializer.toJson<String>(pluginId),
      'agent': serializer.toJson<String?>(agent),
      'modelJson': serializer.toJson<String?>(modelJson),
      'variant': serializer.toJson<String?>(variant),
      'fastMode': serializer.toJson<bool>(fastMode),
      'dedicatedWorktree': serializer.toJson<bool>(dedicatedWorktree),
      'scheduleJson': serializer.toJson<String>(scheduleJson),
      'timeZone': serializer.toJson<String>(timeZone),
      'missedRunPolicy': serializer.toJson<String>(
        $ScheduledTasksTableTable.$convertermissedRunPolicy.toJson(
          missedRunPolicy,
        ),
      ),
      'runMode': serializer.toJson<String>(
        $ScheduledTasksTableTable.$converterrunMode.toJson(runMode),
      ),
      'autoCompact': serializer.toJson<bool>(autoCompact),
      'approvalMode': serializer.toJson<String>(
        $ScheduledTasksTableTable.$converterapprovalMode.toJson(approvalMode),
      ),
      'enabled': serializer.toJson<bool>(enabled),
      'nextDueAt': serializer.toJson<int?>(nextDueAt),
      'targetSessionId': serializer.toJson<String?>(targetSessionId),
      'completedAt': serializer.toJson<int?>(completedAt),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  ScheduledTaskDto copyWith({
    String? id,
    String? name,
    String? promptJson,
    String? projectId,
    String? pluginId,
    Value<String?> agent = const Value.absent(),
    Value<String?> modelJson = const Value.absent(),
    Value<String?> variant = const Value.absent(),
    bool? fastMode,
    bool? dedicatedWorktree,
    String? scheduleJson,
    String? timeZone,
    TaskMissedRunPolicy? missedRunPolicy,
    ScheduledTaskRunModeKind? runMode,
    bool? autoCompact,
    TaskApprovalMode? approvalMode,
    bool? enabled,
    Value<int?> nextDueAt = const Value.absent(),
    Value<String?> targetSessionId = const Value.absent(),
    Value<int?> completedAt = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => ScheduledTaskDto(
    id: id ?? this.id,
    name: name ?? this.name,
    promptJson: promptJson ?? this.promptJson,
    projectId: projectId ?? this.projectId,
    pluginId: pluginId ?? this.pluginId,
    agent: agent.present ? agent.value : this.agent,
    modelJson: modelJson.present ? modelJson.value : this.modelJson,
    variant: variant.present ? variant.value : this.variant,
    fastMode: fastMode ?? this.fastMode,
    dedicatedWorktree: dedicatedWorktree ?? this.dedicatedWorktree,
    scheduleJson: scheduleJson ?? this.scheduleJson,
    timeZone: timeZone ?? this.timeZone,
    missedRunPolicy: missedRunPolicy ?? this.missedRunPolicy,
    runMode: runMode ?? this.runMode,
    autoCompact: autoCompact ?? this.autoCompact,
    approvalMode: approvalMode ?? this.approvalMode,
    enabled: enabled ?? this.enabled,
    nextDueAt: nextDueAt.present ? nextDueAt.value : this.nextDueAt,
    targetSessionId: targetSessionId.present
        ? targetSessionId.value
        : this.targetSessionId,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ScheduledTaskDto copyWithCompanion(ScheduledTasksTableCompanion data) {
    return ScheduledTaskDto(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      promptJson: data.promptJson.present
          ? data.promptJson.value
          : this.promptJson,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      pluginId: data.pluginId.present ? data.pluginId.value : this.pluginId,
      agent: data.agent.present ? data.agent.value : this.agent,
      modelJson: data.modelJson.present ? data.modelJson.value : this.modelJson,
      variant: data.variant.present ? data.variant.value : this.variant,
      fastMode: data.fastMode.present ? data.fastMode.value : this.fastMode,
      dedicatedWorktree: data.dedicatedWorktree.present
          ? data.dedicatedWorktree.value
          : this.dedicatedWorktree,
      scheduleJson: data.scheduleJson.present
          ? data.scheduleJson.value
          : this.scheduleJson,
      timeZone: data.timeZone.present ? data.timeZone.value : this.timeZone,
      missedRunPolicy: data.missedRunPolicy.present
          ? data.missedRunPolicy.value
          : this.missedRunPolicy,
      runMode: data.runMode.present ? data.runMode.value : this.runMode,
      autoCompact: data.autoCompact.present
          ? data.autoCompact.value
          : this.autoCompact,
      approvalMode: data.approvalMode.present
          ? data.approvalMode.value
          : this.approvalMode,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      nextDueAt: data.nextDueAt.present ? data.nextDueAt.value : this.nextDueAt,
      targetSessionId: data.targetSessionId.present
          ? data.targetSessionId.value
          : this.targetSessionId,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledTaskDto(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('promptJson: $promptJson, ')
          ..write('projectId: $projectId, ')
          ..write('pluginId: $pluginId, ')
          ..write('agent: $agent, ')
          ..write('modelJson: $modelJson, ')
          ..write('variant: $variant, ')
          ..write('fastMode: $fastMode, ')
          ..write('dedicatedWorktree: $dedicatedWorktree, ')
          ..write('scheduleJson: $scheduleJson, ')
          ..write('timeZone: $timeZone, ')
          ..write('missedRunPolicy: $missedRunPolicy, ')
          ..write('runMode: $runMode, ')
          ..write('autoCompact: $autoCompact, ')
          ..write('approvalMode: $approvalMode, ')
          ..write('enabled: $enabled, ')
          ..write('nextDueAt: $nextDueAt, ')
          ..write('targetSessionId: $targetSessionId, ')
          ..write('completedAt: $completedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    promptJson,
    projectId,
    pluginId,
    agent,
    modelJson,
    variant,
    fastMode,
    dedicatedWorktree,
    scheduleJson,
    timeZone,
    missedRunPolicy,
    runMode,
    autoCompact,
    approvalMode,
    enabled,
    nextDueAt,
    targetSessionId,
    completedAt,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduledTaskDto &&
          other.id == this.id &&
          other.name == this.name &&
          other.promptJson == this.promptJson &&
          other.projectId == this.projectId &&
          other.pluginId == this.pluginId &&
          other.agent == this.agent &&
          other.modelJson == this.modelJson &&
          other.variant == this.variant &&
          other.fastMode == this.fastMode &&
          other.dedicatedWorktree == this.dedicatedWorktree &&
          other.scheduleJson == this.scheduleJson &&
          other.timeZone == this.timeZone &&
          other.missedRunPolicy == this.missedRunPolicy &&
          other.runMode == this.runMode &&
          other.autoCompact == this.autoCompact &&
          other.approvalMode == this.approvalMode &&
          other.enabled == this.enabled &&
          other.nextDueAt == this.nextDueAt &&
          other.targetSessionId == this.targetSessionId &&
          other.completedAt == this.completedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ScheduledTasksTableCompanion extends UpdateCompanion<ScheduledTaskDto> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> promptJson;
  final Value<String> projectId;
  final Value<String> pluginId;
  final Value<String?> agent;
  final Value<String?> modelJson;
  final Value<String?> variant;
  final Value<bool> fastMode;
  final Value<bool> dedicatedWorktree;
  final Value<String> scheduleJson;
  final Value<String> timeZone;
  final Value<TaskMissedRunPolicy> missedRunPolicy;
  final Value<ScheduledTaskRunModeKind> runMode;
  final Value<bool> autoCompact;
  final Value<TaskApprovalMode> approvalMode;
  final Value<bool> enabled;
  final Value<int?> nextDueAt;
  final Value<String?> targetSessionId;
  final Value<int?> completedAt;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  const ScheduledTasksTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.promptJson = const Value.absent(),
    this.projectId = const Value.absent(),
    this.pluginId = const Value.absent(),
    this.agent = const Value.absent(),
    this.modelJson = const Value.absent(),
    this.variant = const Value.absent(),
    this.fastMode = const Value.absent(),
    this.dedicatedWorktree = const Value.absent(),
    this.scheduleJson = const Value.absent(),
    this.timeZone = const Value.absent(),
    this.missedRunPolicy = const Value.absent(),
    this.runMode = const Value.absent(),
    this.autoCompact = const Value.absent(),
    this.approvalMode = const Value.absent(),
    this.enabled = const Value.absent(),
    this.nextDueAt = const Value.absent(),
    this.targetSessionId = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ScheduledTasksTableCompanion.insert({
    required String id,
    required String name,
    required String promptJson,
    required String projectId,
    required String pluginId,
    this.agent = const Value.absent(),
    this.modelJson = const Value.absent(),
    this.variant = const Value.absent(),
    required bool fastMode,
    required bool dedicatedWorktree,
    required String scheduleJson,
    required String timeZone,
    required TaskMissedRunPolicy missedRunPolicy,
    required ScheduledTaskRunModeKind runMode,
    required bool autoCompact,
    required TaskApprovalMode approvalMode,
    required bool enabled,
    this.nextDueAt = const Value.absent(),
    this.targetSessionId = const Value.absent(),
    this.completedAt = const Value.absent(),
    required int createdAt,
    required int updatedAt,
  }) : id = Value(id),
       name = Value(name),
       promptJson = Value(promptJson),
       projectId = Value(projectId),
       pluginId = Value(pluginId),
       fastMode = Value(fastMode),
       dedicatedWorktree = Value(dedicatedWorktree),
       scheduleJson = Value(scheduleJson),
       timeZone = Value(timeZone),
       missedRunPolicy = Value(missedRunPolicy),
       runMode = Value(runMode),
       autoCompact = Value(autoCompact),
       approvalMode = Value(approvalMode),
       enabled = Value(enabled),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ScheduledTaskDto> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? promptJson,
    Expression<String>? projectId,
    Expression<String>? pluginId,
    Expression<String>? agent,
    Expression<String>? modelJson,
    Expression<String>? variant,
    Expression<bool>? fastMode,
    Expression<bool>? dedicatedWorktree,
    Expression<String>? scheduleJson,
    Expression<String>? timeZone,
    Expression<String>? missedRunPolicy,
    Expression<String>? runMode,
    Expression<bool>? autoCompact,
    Expression<String>? approvalMode,
    Expression<bool>? enabled,
    Expression<int>? nextDueAt,
    Expression<String>? targetSessionId,
    Expression<int>? completedAt,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (promptJson != null) 'prompt_json': promptJson,
      if (projectId != null) 'project_id': projectId,
      if (pluginId != null) 'plugin_id': pluginId,
      if (agent != null) 'agent': agent,
      if (modelJson != null) 'model_json': modelJson,
      if (variant != null) 'variant': variant,
      if (fastMode != null) 'fast_mode': fastMode,
      if (dedicatedWorktree != null) 'dedicated_worktree': dedicatedWorktree,
      if (scheduleJson != null) 'schedule_json': scheduleJson,
      if (timeZone != null) 'time_zone': timeZone,
      if (missedRunPolicy != null) 'missed_run_policy': missedRunPolicy,
      if (runMode != null) 'run_mode': runMode,
      if (autoCompact != null) 'auto_compact': autoCompact,
      if (approvalMode != null) 'approval_mode': approvalMode,
      if (enabled != null) 'enabled': enabled,
      if (nextDueAt != null) 'next_due_at': nextDueAt,
      if (targetSessionId != null) 'target_session_id': targetSessionId,
      if (completedAt != null) 'completed_at': completedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ScheduledTasksTableCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? promptJson,
    Value<String>? projectId,
    Value<String>? pluginId,
    Value<String?>? agent,
    Value<String?>? modelJson,
    Value<String?>? variant,
    Value<bool>? fastMode,
    Value<bool>? dedicatedWorktree,
    Value<String>? scheduleJson,
    Value<String>? timeZone,
    Value<TaskMissedRunPolicy>? missedRunPolicy,
    Value<ScheduledTaskRunModeKind>? runMode,
    Value<bool>? autoCompact,
    Value<TaskApprovalMode>? approvalMode,
    Value<bool>? enabled,
    Value<int?>? nextDueAt,
    Value<String?>? targetSessionId,
    Value<int?>? completedAt,
    Value<int>? createdAt,
    Value<int>? updatedAt,
  }) {
    return ScheduledTasksTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      promptJson: promptJson ?? this.promptJson,
      projectId: projectId ?? this.projectId,
      pluginId: pluginId ?? this.pluginId,
      agent: agent ?? this.agent,
      modelJson: modelJson ?? this.modelJson,
      variant: variant ?? this.variant,
      fastMode: fastMode ?? this.fastMode,
      dedicatedWorktree: dedicatedWorktree ?? this.dedicatedWorktree,
      scheduleJson: scheduleJson ?? this.scheduleJson,
      timeZone: timeZone ?? this.timeZone,
      missedRunPolicy: missedRunPolicy ?? this.missedRunPolicy,
      runMode: runMode ?? this.runMode,
      autoCompact: autoCompact ?? this.autoCompact,
      approvalMode: approvalMode ?? this.approvalMode,
      enabled: enabled ?? this.enabled,
      nextDueAt: nextDueAt ?? this.nextDueAt,
      targetSessionId: targetSessionId ?? this.targetSessionId,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (promptJson.present) {
      map['prompt_json'] = Variable<String>(promptJson.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (pluginId.present) {
      map['plugin_id'] = Variable<String>(pluginId.value);
    }
    if (agent.present) {
      map['agent'] = Variable<String>(agent.value);
    }
    if (modelJson.present) {
      map['model_json'] = Variable<String>(modelJson.value);
    }
    if (variant.present) {
      map['variant'] = Variable<String>(variant.value);
    }
    if (fastMode.present) {
      map['fast_mode'] = Variable<bool>(fastMode.value);
    }
    if (dedicatedWorktree.present) {
      map['dedicated_worktree'] = Variable<bool>(dedicatedWorktree.value);
    }
    if (scheduleJson.present) {
      map['schedule_json'] = Variable<String>(scheduleJson.value);
    }
    if (timeZone.present) {
      map['time_zone'] = Variable<String>(timeZone.value);
    }
    if (missedRunPolicy.present) {
      map['missed_run_policy'] = Variable<String>(
        $ScheduledTasksTableTable.$convertermissedRunPolicy.toSql(
          missedRunPolicy.value,
        ),
      );
    }
    if (runMode.present) {
      map['run_mode'] = Variable<String>(
        $ScheduledTasksTableTable.$converterrunMode.toSql(runMode.value),
      );
    }
    if (autoCompact.present) {
      map['auto_compact'] = Variable<bool>(autoCompact.value);
    }
    if (approvalMode.present) {
      map['approval_mode'] = Variable<String>(
        $ScheduledTasksTableTable.$converterapprovalMode.toSql(
          approvalMode.value,
        ),
      );
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (nextDueAt.present) {
      map['next_due_at'] = Variable<int>(nextDueAt.value);
    }
    if (targetSessionId.present) {
      map['target_session_id'] = Variable<String>(targetSessionId.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledTasksTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('promptJson: $promptJson, ')
          ..write('projectId: $projectId, ')
          ..write('pluginId: $pluginId, ')
          ..write('agent: $agent, ')
          ..write('modelJson: $modelJson, ')
          ..write('variant: $variant, ')
          ..write('fastMode: $fastMode, ')
          ..write('dedicatedWorktree: $dedicatedWorktree, ')
          ..write('scheduleJson: $scheduleJson, ')
          ..write('timeZone: $timeZone, ')
          ..write('missedRunPolicy: $missedRunPolicy, ')
          ..write('runMode: $runMode, ')
          ..write('autoCompact: $autoCompact, ')
          ..write('approvalMode: $approvalMode, ')
          ..write('enabled: $enabled, ')
          ..write('nextDueAt: $nextDueAt, ')
          ..write('targetSessionId: $targetSessionId, ')
          ..write('completedAt: $completedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
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

  /// Whether the session's turns run in the backend's fast mode. The bridge
  /// owns this choice: only client create/prompt/command requests write it;
  /// backend-reported prompt defaults never do.
  bool get fastMode;
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

  /// The bridge-owned title override from an explicit rename or a
  /// title-bearing `session.updated` event. This wins over the latest observed
  /// catalog title for every plugin. Null means the catalog title is rendered.
  String? get title;
  String? get catalogTitle;

  /// How this session answers permission requests when it differs from the
  /// bridge-wide YOLO setting. Null follows that setting.
  SessionApprovalMode? get approvalOverride;

  /// Whether the user pinned this root session above the time-ordered list.
  /// Only an unarchived root is pinned; archiving drops the pin.
  bool get pinned;

  /// The task whose run started this session. Null for every other session,
  /// and once that task is deleted, leaving an ordinary session.
  String? get scheduledTaskId;
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
    map['fast_mode'] = Variable<bool>(fastMode);
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
    if (!nullToAbsent || approvalOverride != null) {
      map['approval_override'] = Variable<String>(
        $SessionTableTable.$converterapprovalOverriden.toSql(approvalOverride),
      );
    }
    map['pinned'] = Variable<bool>(pinned);
    if (!nullToAbsent || scheduledTaskId != null) {
      map['scheduled_task_id'] = Variable<String>(scheduledTaskId);
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
  static const VerificationMeta _fastModeMeta = const VerificationMeta(
    'fastMode',
  );
  @override
  late final GeneratedColumn<bool> fastMode = GeneratedColumn<bool>(
    'fast_mode',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("fast_mode" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  late final GeneratedColumnWithTypeConverter<SessionApprovalMode?, String>
  approvalOverride =
      GeneratedColumn<String>(
        'approval_override',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<SessionApprovalMode?>(
        $SessionTableTable.$converterapprovalOverriden,
      );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _scheduledTaskIdMeta = const VerificationMeta(
    'scheduledTaskId',
  );
  @override
  late final GeneratedColumn<String> scheduledTaskId = GeneratedColumn<String>(
    'scheduled_task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES scheduled_tasks (id) ON DELETE SET NULL',
    ),
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
    fastMode,
    createdAt,
    updatedAt,
    projectionUpdatedAt,
    lastActivityAt,
    lastSeenAt,
    lastUserMessageAt,
    pluginId,
    title,
    catalogTitle,
    approvalOverride,
    pinned,
    scheduledTaskId,
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
    if (data.containsKey('fast_mode')) {
      context.handle(
        _fastModeMeta,
        fastMode.isAcceptableOrUnknown(data['fast_mode']!, _fastModeMeta),
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
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    if (data.containsKey('scheduled_task_id')) {
      context.handle(
        _scheduledTaskIdMeta,
        scheduledTaskId.isAcceptableOrUnknown(
          data['scheduled_task_id']!,
          _scheduledTaskIdMeta,
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
      fastMode: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}fast_mode'],
      )!,
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
      approvalOverride: $SessionTableTable.$converterapprovalOverriden.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}approval_override'],
        ),
      ),
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
      scheduledTaskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheduled_task_id'],
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
  static JsonTypeConverter2<SessionApprovalMode, String, String>
  $converterapprovalOverride = const EnumNameConverter<SessionApprovalMode>(
    SessionApprovalMode.values,
  );
  static JsonTypeConverter2<SessionApprovalMode?, String?, String?>
  $converterapprovalOverriden = JsonTypeConverter2.asNullable(
    $converterapprovalOverride,
  );
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
  final Value<bool> fastMode;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> projectionUpdatedAt;
  final Value<int?> lastActivityAt;
  final Value<int?> lastSeenAt;
  final Value<int?> lastUserMessageAt;
  final Value<String> pluginId;
  final Value<String?> title;
  final Value<String?> catalogTitle;
  final Value<SessionApprovalMode?> approvalOverride;
  final Value<bool> pinned;
  final Value<String?> scheduledTaskId;
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
    this.fastMode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.projectionUpdatedAt = const Value.absent(),
    this.lastActivityAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.lastUserMessageAt = const Value.absent(),
    this.pluginId = const Value.absent(),
    this.title = const Value.absent(),
    this.catalogTitle = const Value.absent(),
    this.approvalOverride = const Value.absent(),
    this.pinned = const Value.absent(),
    this.scheduledTaskId = const Value.absent(),
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
    this.fastMode = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    required int projectionUpdatedAt,
    this.lastActivityAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.lastUserMessageAt = const Value.absent(),
    required String pluginId,
    this.title = const Value.absent(),
    this.catalogTitle = const Value.absent(),
    this.approvalOverride = const Value.absent(),
    this.pinned = const Value.absent(),
    this.scheduledTaskId = const Value.absent(),
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
    Expression<bool>? fastMode,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? projectionUpdatedAt,
    Expression<int>? lastActivityAt,
    Expression<int>? lastSeenAt,
    Expression<int>? lastUserMessageAt,
    Expression<String>? pluginId,
    Expression<String>? title,
    Expression<String>? catalogTitle,
    Expression<String>? approvalOverride,
    Expression<bool>? pinned,
    Expression<String>? scheduledTaskId,
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
      if (fastMode != null) 'fast_mode': fastMode,
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
      if (approvalOverride != null) 'approval_override': approvalOverride,
      if (pinned != null) 'pinned': pinned,
      if (scheduledTaskId != null) 'scheduled_task_id': scheduledTaskId,
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
    Value<bool>? fastMode,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? projectionUpdatedAt,
    Value<int?>? lastActivityAt,
    Value<int?>? lastSeenAt,
    Value<int?>? lastUserMessageAt,
    Value<String>? pluginId,
    Value<String?>? title,
    Value<String?>? catalogTitle,
    Value<SessionApprovalMode?>? approvalOverride,
    Value<bool>? pinned,
    Value<String?>? scheduledTaskId,
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
      fastMode: fastMode ?? this.fastMode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      projectionUpdatedAt: projectionUpdatedAt ?? this.projectionUpdatedAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lastUserMessageAt: lastUserMessageAt ?? this.lastUserMessageAt,
      pluginId: pluginId ?? this.pluginId,
      title: title ?? this.title,
      catalogTitle: catalogTitle ?? this.catalogTitle,
      approvalOverride: approvalOverride ?? this.approvalOverride,
      pinned: pinned ?? this.pinned,
      scheduledTaskId: scheduledTaskId ?? this.scheduledTaskId,
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
    if (fastMode.present) {
      map['fast_mode'] = Variable<bool>(fastMode.value);
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
    if (approvalOverride.present) {
      map['approval_override'] = Variable<String>(
        $SessionTableTable.$converterapprovalOverriden.toSql(
          approvalOverride.value,
        ),
      );
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (scheduledTaskId.present) {
      map['scheduled_task_id'] = Variable<String>(scheduledTaskId.value);
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
          ..write('fastMode: $fastMode, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('projectionUpdatedAt: $projectionUpdatedAt, ')
          ..write('lastActivityAt: $lastActivityAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('lastUserMessageAt: $lastUserMessageAt, ')
          ..write('pluginId: $pluginId, ')
          ..write('title: $title, ')
          ..write('catalogTitle: $catalogTitle, ')
          ..write('approvalOverride: $approvalOverride, ')
          ..write('pinned: $pinned, ')
          ..write('scheduledTaskId: $scheduledTaskId')
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

mixin $SessionOptionsCacheTableTableToColumns
    implements Insertable<SessionOptionsCacheTableData> {
  String get pluginId;
  PluginSessionOptionsScope get scope;
  String get ownerId;
  String? get projectId;
  String? get capturedProjectPath;
  int get revision;
  int get capturedAt;
  String get agentsJson;
  String get providersJson;
  String get commandsJson;
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['plugin_id'] = Variable<String>(pluginId);
    {
      map['scope'] = Variable<String>(
        $SessionOptionsCacheTableTable.$converterscope.toSql(scope),
      );
    }
    map['owner_id'] = Variable<String>(ownerId);
    if (!nullToAbsent || projectId != null) {
      map['project_id'] = Variable<String>(projectId);
    }
    if (!nullToAbsent || capturedProjectPath != null) {
      map['captured_project_path'] = Variable<String>(capturedProjectPath);
    }
    map['revision'] = Variable<int>(revision);
    map['captured_at'] = Variable<int>(capturedAt);
    map['agents_json'] = Variable<String>(agentsJson);
    map['providers_json'] = Variable<String>(providersJson);
    map['commands_json'] = Variable<String>(commandsJson);
    return map;
  }
}

class $SessionOptionsCacheTableTable extends SessionOptionsCacheTable
    with
        TableInfo<
          $SessionOptionsCacheTableTable,
          SessionOptionsCacheTableData
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionOptionsCacheTableTable(this.attachedDatabase, [this._alias]);
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
  @override
  late final GeneratedColumnWithTypeConverter<PluginSessionOptionsScope, String>
  scope =
      GeneratedColumn<String>(
        'scope',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<PluginSessionOptionsScope>(
        $SessionOptionsCacheTableTable.$converterscope,
      );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints:
        'NULL REFERENCES projects_table (project_id) ON DELETE CASCADE',
  );
  static const VerificationMeta _capturedProjectPathMeta =
      const VerificationMeta('capturedProjectPath');
  @override
  late final GeneratedColumn<String> capturedProjectPath =
      GeneratedColumn<String>(
        'captured_project_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<int> capturedAt = GeneratedColumn<int>(
    'captured_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _agentsJsonMeta = const VerificationMeta(
    'agentsJson',
  );
  @override
  late final GeneratedColumn<String> agentsJson = GeneratedColumn<String>(
    'agents_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providersJsonMeta = const VerificationMeta(
    'providersJson',
  );
  @override
  late final GeneratedColumn<String> providersJson = GeneratedColumn<String>(
    'providers_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commandsJsonMeta = const VerificationMeta(
    'commandsJson',
  );
  @override
  late final GeneratedColumn<String> commandsJson = GeneratedColumn<String>(
    'commands_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    pluginId,
    scope,
    ownerId,
    projectId,
    capturedProjectPath,
    revision,
    capturedAt,
    agentsJson,
    providersJson,
    commandsJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_options_cache_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionOptionsCacheTableData> instance, {
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
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    }
    if (data.containsKey('captured_project_path')) {
      context.handle(
        _capturedProjectPathMeta,
        capturedProjectPath.isAcceptableOrUnknown(
          data['captured_project_path']!,
          _capturedProjectPathMeta,
        ),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_capturedAtMeta);
    }
    if (data.containsKey('agents_json')) {
      context.handle(
        _agentsJsonMeta,
        agentsJson.isAcceptableOrUnknown(data['agents_json']!, _agentsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_agentsJsonMeta);
    }
    if (data.containsKey('providers_json')) {
      context.handle(
        _providersJsonMeta,
        providersJson.isAcceptableOrUnknown(
          data['providers_json']!,
          _providersJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providersJsonMeta);
    }
    if (data.containsKey('commands_json')) {
      context.handle(
        _commandsJsonMeta,
        commandsJson.isAcceptableOrUnknown(
          data['commands_json']!,
          _commandsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_commandsJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pluginId, scope, ownerId};
  @override
  SessionOptionsCacheTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionOptionsCacheTableData(
      pluginId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plugin_id'],
      )!,
      scope: $SessionOptionsCacheTableTable.$converterscope.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}scope'],
        )!,
      ),
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      ),
      capturedProjectPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}captured_project_path'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}captured_at'],
      )!,
      agentsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agents_json'],
      )!,
      providersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}providers_json'],
      )!,
      commandsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}commands_json'],
      )!,
    );
  }

  @override
  $SessionOptionsCacheTableTable createAlias(String alias) {
    return $SessionOptionsCacheTableTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PluginSessionOptionsScope, String, String>
  $converterscope = const EnumNameConverter<PluginSessionOptionsScope>(
    PluginSessionOptionsScope.values,
  );
  @override
  bool get withoutRowId => true;
}

class SessionOptionsCacheTableData extends DataClass
    with $SessionOptionsCacheTableTableToColumns {
  @override
  final String pluginId;
  @override
  final PluginSessionOptionsScope scope;
  @override
  final String ownerId;
  @override
  final String? projectId;
  @override
  final String? capturedProjectPath;
  @override
  final int revision;
  @override
  final int capturedAt;
  @override
  final String agentsJson;
  @override
  final String providersJson;
  @override
  final String commandsJson;
  const SessionOptionsCacheTableData({
    required this.pluginId,
    required this.scope,
    required this.ownerId,
    this.projectId,
    this.capturedProjectPath,
    required this.revision,
    required this.capturedAt,
    required this.agentsJson,
    required this.providersJson,
    required this.commandsJson,
  });
  SessionOptionsCacheTableCompanion toCompanion(bool nullToAbsent) {
    return SessionOptionsCacheTableCompanion(
      pluginId: Value(pluginId),
      scope: Value(scope),
      ownerId: Value(ownerId),
      projectId: projectId == null && nullToAbsent
          ? const Value.absent()
          : Value(projectId),
      capturedProjectPath: capturedProjectPath == null && nullToAbsent
          ? const Value.absent()
          : Value(capturedProjectPath),
      revision: Value(revision),
      capturedAt: Value(capturedAt),
      agentsJson: Value(agentsJson),
      providersJson: Value(providersJson),
      commandsJson: Value(commandsJson),
    );
  }

  factory SessionOptionsCacheTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionOptionsCacheTableData(
      pluginId: serializer.fromJson<String>(json['pluginId']),
      scope: $SessionOptionsCacheTableTable.$converterscope.fromJson(
        serializer.fromJson<String>(json['scope']),
      ),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      projectId: serializer.fromJson<String?>(json['projectId']),
      capturedProjectPath: serializer.fromJson<String?>(
        json['capturedProjectPath'],
      ),
      revision: serializer.fromJson<int>(json['revision']),
      capturedAt: serializer.fromJson<int>(json['capturedAt']),
      agentsJson: serializer.fromJson<String>(json['agentsJson']),
      providersJson: serializer.fromJson<String>(json['providersJson']),
      commandsJson: serializer.fromJson<String>(json['commandsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'pluginId': serializer.toJson<String>(pluginId),
      'scope': serializer.toJson<String>(
        $SessionOptionsCacheTableTable.$converterscope.toJson(scope),
      ),
      'ownerId': serializer.toJson<String>(ownerId),
      'projectId': serializer.toJson<String?>(projectId),
      'capturedProjectPath': serializer.toJson<String?>(capturedProjectPath),
      'revision': serializer.toJson<int>(revision),
      'capturedAt': serializer.toJson<int>(capturedAt),
      'agentsJson': serializer.toJson<String>(agentsJson),
      'providersJson': serializer.toJson<String>(providersJson),
      'commandsJson': serializer.toJson<String>(commandsJson),
    };
  }

  SessionOptionsCacheTableData copyWith({
    String? pluginId,
    PluginSessionOptionsScope? scope,
    String? ownerId,
    Value<String?> projectId = const Value.absent(),
    Value<String?> capturedProjectPath = const Value.absent(),
    int? revision,
    int? capturedAt,
    String? agentsJson,
    String? providersJson,
    String? commandsJson,
  }) => SessionOptionsCacheTableData(
    pluginId: pluginId ?? this.pluginId,
    scope: scope ?? this.scope,
    ownerId: ownerId ?? this.ownerId,
    projectId: projectId.present ? projectId.value : this.projectId,
    capturedProjectPath: capturedProjectPath.present
        ? capturedProjectPath.value
        : this.capturedProjectPath,
    revision: revision ?? this.revision,
    capturedAt: capturedAt ?? this.capturedAt,
    agentsJson: agentsJson ?? this.agentsJson,
    providersJson: providersJson ?? this.providersJson,
    commandsJson: commandsJson ?? this.commandsJson,
  );
  SessionOptionsCacheTableData copyWithCompanion(
    SessionOptionsCacheTableCompanion data,
  ) {
    return SessionOptionsCacheTableData(
      pluginId: data.pluginId.present ? data.pluginId.value : this.pluginId,
      scope: data.scope.present ? data.scope.value : this.scope,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      capturedProjectPath: data.capturedProjectPath.present
          ? data.capturedProjectPath.value
          : this.capturedProjectPath,
      revision: data.revision.present ? data.revision.value : this.revision,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      agentsJson: data.agentsJson.present
          ? data.agentsJson.value
          : this.agentsJson,
      providersJson: data.providersJson.present
          ? data.providersJson.value
          : this.providersJson,
      commandsJson: data.commandsJson.present
          ? data.commandsJson.value
          : this.commandsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionOptionsCacheTableData(')
          ..write('pluginId: $pluginId, ')
          ..write('scope: $scope, ')
          ..write('ownerId: $ownerId, ')
          ..write('projectId: $projectId, ')
          ..write('capturedProjectPath: $capturedProjectPath, ')
          ..write('revision: $revision, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('agentsJson: $agentsJson, ')
          ..write('providersJson: $providersJson, ')
          ..write('commandsJson: $commandsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    pluginId,
    scope,
    ownerId,
    projectId,
    capturedProjectPath,
    revision,
    capturedAt,
    agentsJson,
    providersJson,
    commandsJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionOptionsCacheTableData &&
          other.pluginId == this.pluginId &&
          other.scope == this.scope &&
          other.ownerId == this.ownerId &&
          other.projectId == this.projectId &&
          other.capturedProjectPath == this.capturedProjectPath &&
          other.revision == this.revision &&
          other.capturedAt == this.capturedAt &&
          other.agentsJson == this.agentsJson &&
          other.providersJson == this.providersJson &&
          other.commandsJson == this.commandsJson);
}

class SessionOptionsCacheTableCompanion
    extends UpdateCompanion<SessionOptionsCacheTableData> {
  final Value<String> pluginId;
  final Value<PluginSessionOptionsScope> scope;
  final Value<String> ownerId;
  final Value<String?> projectId;
  final Value<String?> capturedProjectPath;
  final Value<int> revision;
  final Value<int> capturedAt;
  final Value<String> agentsJson;
  final Value<String> providersJson;
  final Value<String> commandsJson;
  const SessionOptionsCacheTableCompanion({
    this.pluginId = const Value.absent(),
    this.scope = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.capturedProjectPath = const Value.absent(),
    this.revision = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.agentsJson = const Value.absent(),
    this.providersJson = const Value.absent(),
    this.commandsJson = const Value.absent(),
  });
  SessionOptionsCacheTableCompanion.insert({
    required String pluginId,
    required PluginSessionOptionsScope scope,
    required String ownerId,
    this.projectId = const Value.absent(),
    this.capturedProjectPath = const Value.absent(),
    required int revision,
    required int capturedAt,
    required String agentsJson,
    required String providersJson,
    required String commandsJson,
  }) : pluginId = Value(pluginId),
       scope = Value(scope),
       ownerId = Value(ownerId),
       revision = Value(revision),
       capturedAt = Value(capturedAt),
       agentsJson = Value(agentsJson),
       providersJson = Value(providersJson),
       commandsJson = Value(commandsJson);
  static Insertable<SessionOptionsCacheTableData> custom({
    Expression<String>? pluginId,
    Expression<String>? scope,
    Expression<String>? ownerId,
    Expression<String>? projectId,
    Expression<String>? capturedProjectPath,
    Expression<int>? revision,
    Expression<int>? capturedAt,
    Expression<String>? agentsJson,
    Expression<String>? providersJson,
    Expression<String>? commandsJson,
  }) {
    return RawValuesInsertable({
      if (pluginId != null) 'plugin_id': pluginId,
      if (scope != null) 'scope': scope,
      if (ownerId != null) 'owner_id': ownerId,
      if (projectId != null) 'project_id': projectId,
      if (capturedProjectPath != null)
        'captured_project_path': capturedProjectPath,
      if (revision != null) 'revision': revision,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (agentsJson != null) 'agents_json': agentsJson,
      if (providersJson != null) 'providers_json': providersJson,
      if (commandsJson != null) 'commands_json': commandsJson,
    });
  }

  SessionOptionsCacheTableCompanion copyWith({
    Value<String>? pluginId,
    Value<PluginSessionOptionsScope>? scope,
    Value<String>? ownerId,
    Value<String?>? projectId,
    Value<String?>? capturedProjectPath,
    Value<int>? revision,
    Value<int>? capturedAt,
    Value<String>? agentsJson,
    Value<String>? providersJson,
    Value<String>? commandsJson,
  }) {
    return SessionOptionsCacheTableCompanion(
      pluginId: pluginId ?? this.pluginId,
      scope: scope ?? this.scope,
      ownerId: ownerId ?? this.ownerId,
      projectId: projectId ?? this.projectId,
      capturedProjectPath: capturedProjectPath ?? this.capturedProjectPath,
      revision: revision ?? this.revision,
      capturedAt: capturedAt ?? this.capturedAt,
      agentsJson: agentsJson ?? this.agentsJson,
      providersJson: providersJson ?? this.providersJson,
      commandsJson: commandsJson ?? this.commandsJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pluginId.present) {
      map['plugin_id'] = Variable<String>(pluginId.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(
        $SessionOptionsCacheTableTable.$converterscope.toSql(scope.value),
      );
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (capturedProjectPath.present) {
      map['captured_project_path'] = Variable<String>(
        capturedProjectPath.value,
      );
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<int>(capturedAt.value);
    }
    if (agentsJson.present) {
      map['agents_json'] = Variable<String>(agentsJson.value);
    }
    if (providersJson.present) {
      map['providers_json'] = Variable<String>(providersJson.value);
    }
    if (commandsJson.present) {
      map['commands_json'] = Variable<String>(commandsJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionOptionsCacheTableCompanion(')
          ..write('pluginId: $pluginId, ')
          ..write('scope: $scope, ')
          ..write('ownerId: $ownerId, ')
          ..write('projectId: $projectId, ')
          ..write('capturedProjectPath: $capturedProjectPath, ')
          ..write('revision: $revision, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('agentsJson: $agentsJson, ')
          ..write('providersJson: $providersJson, ')
          ..write('commandsJson: $commandsJson')
          ..write(')'))
        .toString();
  }
}

mixin $NewSessionDefaultsTableTableToColumns
    implements Insertable<NewSessionDefaultsTableData> {
  String get pluginId;
  String? get agent;
  AgentModel? get agentModel;
  bool get fastMode;
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['plugin_id'] = Variable<String>(pluginId);
    if (!nullToAbsent || agent != null) {
      map['agent'] = Variable<String>(agent);
    }
    if (!nullToAbsent || agentModel != null) {
      map['agent_model'] = Variable<String>(
        $NewSessionDefaultsTableTable.$converteragentModeln.toSql(agentModel),
      );
    }
    map['fast_mode'] = Variable<bool>(fastMode);
    return map;
  }
}

class $NewSessionDefaultsTableTable extends NewSessionDefaultsTable
    with TableInfo<$NewSessionDefaultsTableTable, NewSessionDefaultsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NewSessionDefaultsTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _agentMeta = const VerificationMeta('agent');
  @override
  late final GeneratedColumn<String> agent = GeneratedColumn<String>(
    'agent',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AgentModel?, String> agentModel =
      GeneratedColumn<String>(
        'agent_model',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<AgentModel?>(
        $NewSessionDefaultsTableTable.$converteragentModeln,
      );
  static const VerificationMeta _fastModeMeta = const VerificationMeta(
    'fastMode',
  );
  @override
  late final GeneratedColumn<bool> fastMode = GeneratedColumn<bool>(
    'fast_mode',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("fast_mode" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [pluginId, agent, agentModel, fastMode];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'new_session_defaults_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<NewSessionDefaultsTableData> instance, {
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
    if (data.containsKey('agent')) {
      context.handle(
        _agentMeta,
        agent.isAcceptableOrUnknown(data['agent']!, _agentMeta),
      );
    }
    if (data.containsKey('fast_mode')) {
      context.handle(
        _fastModeMeta,
        fastMode.isAcceptableOrUnknown(data['fast_mode']!, _fastModeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pluginId};
  @override
  NewSessionDefaultsTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NewSessionDefaultsTableData(
      pluginId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plugin_id'],
      )!,
      agent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent'],
      ),
      agentModel: $NewSessionDefaultsTableTable.$converteragentModeln.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}agent_model'],
        ),
      ),
      fastMode: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}fast_mode'],
      )!,
    );
  }

  @override
  $NewSessionDefaultsTableTable createAlias(String alias) {
    return $NewSessionDefaultsTableTable(attachedDatabase, alias);
  }

  static TypeConverter<AgentModel, String> $converteragentModel =
      const AgentModelConverter();
  static TypeConverter<AgentModel?, String?> $converteragentModeln =
      NullAwareTypeConverter.wrap($converteragentModel);
  @override
  bool get withoutRowId => true;
}

class NewSessionDefaultsTableData extends DataClass
    with $NewSessionDefaultsTableTableToColumns {
  @override
  final String pluginId;
  @override
  final String? agent;
  @override
  final AgentModel? agentModel;
  @override
  final bool fastMode;
  const NewSessionDefaultsTableData({
    required this.pluginId,
    this.agent,
    this.agentModel,
    required this.fastMode,
  });
  NewSessionDefaultsTableCompanion toCompanion(bool nullToAbsent) {
    return NewSessionDefaultsTableCompanion(
      pluginId: Value(pluginId),
      agent: agent == null && nullToAbsent
          ? const Value.absent()
          : Value(agent),
      agentModel: agentModel == null && nullToAbsent
          ? const Value.absent()
          : Value(agentModel),
      fastMode: Value(fastMode),
    );
  }

  factory NewSessionDefaultsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NewSessionDefaultsTableData(
      pluginId: serializer.fromJson<String>(json['pluginId']),
      agent: serializer.fromJson<String?>(json['agent']),
      agentModel: serializer.fromJson<AgentModel?>(json['agentModel']),
      fastMode: serializer.fromJson<bool>(json['fastMode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'pluginId': serializer.toJson<String>(pluginId),
      'agent': serializer.toJson<String?>(agent),
      'agentModel': serializer.toJson<AgentModel?>(agentModel),
      'fastMode': serializer.toJson<bool>(fastMode),
    };
  }

  NewSessionDefaultsTableData copyWith({
    String? pluginId,
    Value<String?> agent = const Value.absent(),
    Value<AgentModel?> agentModel = const Value.absent(),
    bool? fastMode,
  }) => NewSessionDefaultsTableData(
    pluginId: pluginId ?? this.pluginId,
    agent: agent.present ? agent.value : this.agent,
    agentModel: agentModel.present ? agentModel.value : this.agentModel,
    fastMode: fastMode ?? this.fastMode,
  );
  NewSessionDefaultsTableData copyWithCompanion(
    NewSessionDefaultsTableCompanion data,
  ) {
    return NewSessionDefaultsTableData(
      pluginId: data.pluginId.present ? data.pluginId.value : this.pluginId,
      agent: data.agent.present ? data.agent.value : this.agent,
      agentModel: data.agentModel.present
          ? data.agentModel.value
          : this.agentModel,
      fastMode: data.fastMode.present ? data.fastMode.value : this.fastMode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NewSessionDefaultsTableData(')
          ..write('pluginId: $pluginId, ')
          ..write('agent: $agent, ')
          ..write('agentModel: $agentModel, ')
          ..write('fastMode: $fastMode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(pluginId, agent, agentModel, fastMode);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NewSessionDefaultsTableData &&
          other.pluginId == this.pluginId &&
          other.agent == this.agent &&
          other.agentModel == this.agentModel &&
          other.fastMode == this.fastMode);
}

class NewSessionDefaultsTableCompanion
    extends UpdateCompanion<NewSessionDefaultsTableData> {
  final Value<String> pluginId;
  final Value<String?> agent;
  final Value<AgentModel?> agentModel;
  final Value<bool> fastMode;
  const NewSessionDefaultsTableCompanion({
    this.pluginId = const Value.absent(),
    this.agent = const Value.absent(),
    this.agentModel = const Value.absent(),
    this.fastMode = const Value.absent(),
  });
  NewSessionDefaultsTableCompanion.insert({
    required String pluginId,
    this.agent = const Value.absent(),
    this.agentModel = const Value.absent(),
    this.fastMode = const Value.absent(),
  }) : pluginId = Value(pluginId);
  static Insertable<NewSessionDefaultsTableData> custom({
    Expression<String>? pluginId,
    Expression<String>? agent,
    Expression<String>? agentModel,
    Expression<bool>? fastMode,
  }) {
    return RawValuesInsertable({
      if (pluginId != null) 'plugin_id': pluginId,
      if (agent != null) 'agent': agent,
      if (agentModel != null) 'agent_model': agentModel,
      if (fastMode != null) 'fast_mode': fastMode,
    });
  }

  NewSessionDefaultsTableCompanion copyWith({
    Value<String>? pluginId,
    Value<String?>? agent,
    Value<AgentModel?>? agentModel,
    Value<bool>? fastMode,
  }) {
    return NewSessionDefaultsTableCompanion(
      pluginId: pluginId ?? this.pluginId,
      agent: agent ?? this.agent,
      agentModel: agentModel ?? this.agentModel,
      fastMode: fastMode ?? this.fastMode,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pluginId.present) {
      map['plugin_id'] = Variable<String>(pluginId.value);
    }
    if (agent.present) {
      map['agent'] = Variable<String>(agent.value);
    }
    if (agentModel.present) {
      map['agent_model'] = Variable<String>(
        $NewSessionDefaultsTableTable.$converteragentModeln.toSql(
          agentModel.value,
        ),
      );
    }
    if (fastMode.present) {
      map['fast_mode'] = Variable<bool>(fastMode.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NewSessionDefaultsTableCompanion(')
          ..write('pluginId: $pluginId, ')
          ..write('agent: $agent, ')
          ..write('agentModel: $agentModel, ')
          ..write('fastMode: $fastMode')
          ..write(')'))
        .toString();
  }
}

mixin $AcceptedPromptsTableTableToColumns
    implements Insertable<AcceptedPromptsTableData> {
  String get sessionId;
  String get promptId;
  int get acceptedAt;
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['prompt_id'] = Variable<String>(promptId);
    map['accepted_at'] = Variable<int>(acceptedAt);
    return map;
  }
}

class $AcceptedPromptsTableTable extends AcceptedPromptsTable
    with TableInfo<$AcceptedPromptsTableTable, AcceptedPromptsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AcceptedPromptsTableTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _promptIdMeta = const VerificationMeta(
    'promptId',
  );
  @override
  late final GeneratedColumn<String> promptId = GeneratedColumn<String>(
    'prompt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _acceptedAtMeta = const VerificationMeta(
    'acceptedAt',
  );
  @override
  late final GeneratedColumn<int> acceptedAt = GeneratedColumn<int>(
    'accepted_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [sessionId, promptId, acceptedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accepted_prompts_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<AcceptedPromptsTableData> instance, {
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
    if (data.containsKey('prompt_id')) {
      context.handle(
        _promptIdMeta,
        promptId.isAcceptableOrUnknown(data['prompt_id']!, _promptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_promptIdMeta);
    }
    if (data.containsKey('accepted_at')) {
      context.handle(
        _acceptedAtMeta,
        acceptedAt.isAcceptableOrUnknown(data['accepted_at']!, _acceptedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_acceptedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId, promptId};
  @override
  AcceptedPromptsTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AcceptedPromptsTableData(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      promptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt_id'],
      )!,
      acceptedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}accepted_at'],
      )!,
    );
  }

  @override
  $AcceptedPromptsTableTable createAlias(String alias) {
    return $AcceptedPromptsTableTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class AcceptedPromptsTableData extends DataClass
    with $AcceptedPromptsTableTableToColumns {
  @override
  final String sessionId;
  @override
  final String promptId;
  @override
  final int acceptedAt;
  const AcceptedPromptsTableData({
    required this.sessionId,
    required this.promptId,
    required this.acceptedAt,
  });
  AcceptedPromptsTableCompanion toCompanion(bool nullToAbsent) {
    return AcceptedPromptsTableCompanion(
      sessionId: Value(sessionId),
      promptId: Value(promptId),
      acceptedAt: Value(acceptedAt),
    );
  }

  factory AcceptedPromptsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AcceptedPromptsTableData(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      promptId: serializer.fromJson<String>(json['promptId']),
      acceptedAt: serializer.fromJson<int>(json['acceptedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'promptId': serializer.toJson<String>(promptId),
      'acceptedAt': serializer.toJson<int>(acceptedAt),
    };
  }

  AcceptedPromptsTableData copyWith({
    String? sessionId,
    String? promptId,
    int? acceptedAt,
  }) => AcceptedPromptsTableData(
    sessionId: sessionId ?? this.sessionId,
    promptId: promptId ?? this.promptId,
    acceptedAt: acceptedAt ?? this.acceptedAt,
  );
  AcceptedPromptsTableData copyWithCompanion(
    AcceptedPromptsTableCompanion data,
  ) {
    return AcceptedPromptsTableData(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      promptId: data.promptId.present ? data.promptId.value : this.promptId,
      acceptedAt: data.acceptedAt.present
          ? data.acceptedAt.value
          : this.acceptedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AcceptedPromptsTableData(')
          ..write('sessionId: $sessionId, ')
          ..write('promptId: $promptId, ')
          ..write('acceptedAt: $acceptedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sessionId, promptId, acceptedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AcceptedPromptsTableData &&
          other.sessionId == this.sessionId &&
          other.promptId == this.promptId &&
          other.acceptedAt == this.acceptedAt);
}

class AcceptedPromptsTableCompanion
    extends UpdateCompanion<AcceptedPromptsTableData> {
  final Value<String> sessionId;
  final Value<String> promptId;
  final Value<int> acceptedAt;
  const AcceptedPromptsTableCompanion({
    this.sessionId = const Value.absent(),
    this.promptId = const Value.absent(),
    this.acceptedAt = const Value.absent(),
  });
  AcceptedPromptsTableCompanion.insert({
    required String sessionId,
    required String promptId,
    required int acceptedAt,
  }) : sessionId = Value(sessionId),
       promptId = Value(promptId),
       acceptedAt = Value(acceptedAt);
  static Insertable<AcceptedPromptsTableData> custom({
    Expression<String>? sessionId,
    Expression<String>? promptId,
    Expression<int>? acceptedAt,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (promptId != null) 'prompt_id': promptId,
      if (acceptedAt != null) 'accepted_at': acceptedAt,
    });
  }

  AcceptedPromptsTableCompanion copyWith({
    Value<String>? sessionId,
    Value<String>? promptId,
    Value<int>? acceptedAt,
  }) {
    return AcceptedPromptsTableCompanion(
      sessionId: sessionId ?? this.sessionId,
      promptId: promptId ?? this.promptId,
      acceptedAt: acceptedAt ?? this.acceptedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (promptId.present) {
      map['prompt_id'] = Variable<String>(promptId.value);
    }
    if (acceptedAt.present) {
      map['accepted_at'] = Variable<int>(acceptedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AcceptedPromptsTableCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('promptId: $promptId, ')
          ..write('acceptedAt: $acceptedAt')
          ..write(')'))
        .toString();
  }
}

mixin $SessionContinuationTableTableToColumns
    implements Insertable<SessionContinuationDto> {
  String get sessionId;
  bool get enabled;
  String get outcomeJson;
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['enabled'] = Variable<bool>(enabled);
    map['outcome_json'] = Variable<String>(outcomeJson);
    return map;
  }
}

class $SessionContinuationTableTable extends SessionContinuationTable
    with TableInfo<$SessionContinuationTableTable, SessionContinuationDto> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionContinuationTableTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions_table (session_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
  );
  static const VerificationMeta _outcomeJsonMeta = const VerificationMeta(
    'outcomeJson',
  );
  @override
  late final GeneratedColumn<String> outcomeJson = GeneratedColumn<String>(
    'outcome_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [sessionId, enabled, outcomeJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_continuations';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionContinuationDto> instance, {
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
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    } else if (isInserting) {
      context.missing(_enabledMeta);
    }
    if (data.containsKey('outcome_json')) {
      context.handle(
        _outcomeJsonMeta,
        outcomeJson.isAcceptableOrUnknown(
          data['outcome_json']!,
          _outcomeJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_outcomeJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  SessionContinuationDto map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionContinuationDto(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      outcomeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outcome_json'],
      )!,
    );
  }

  @override
  $SessionContinuationTableTable createAlias(String alias) {
    return $SessionContinuationTableTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class SessionContinuationDto extends DataClass
    with $SessionContinuationTableTableToColumns {
  @override
  final String sessionId;
  @override
  final bool enabled;
  @override
  final String outcomeJson;
  const SessionContinuationDto({
    required this.sessionId,
    required this.enabled,
    required this.outcomeJson,
  });
  SessionContinuationTableCompanion toCompanion(bool nullToAbsent) {
    return SessionContinuationTableCompanion(
      sessionId: Value(sessionId),
      enabled: Value(enabled),
      outcomeJson: Value(outcomeJson),
    );
  }

  factory SessionContinuationDto.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionContinuationDto(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      outcomeJson: serializer.fromJson<String>(json['outcomeJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'enabled': serializer.toJson<bool>(enabled),
      'outcomeJson': serializer.toJson<String>(outcomeJson),
    };
  }

  SessionContinuationDto copyWith({
    String? sessionId,
    bool? enabled,
    String? outcomeJson,
  }) => SessionContinuationDto(
    sessionId: sessionId ?? this.sessionId,
    enabled: enabled ?? this.enabled,
    outcomeJson: outcomeJson ?? this.outcomeJson,
  );
  SessionContinuationDto copyWithCompanion(
    SessionContinuationTableCompanion data,
  ) {
    return SessionContinuationDto(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      outcomeJson: data.outcomeJson.present
          ? data.outcomeJson.value
          : this.outcomeJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionContinuationDto(')
          ..write('sessionId: $sessionId, ')
          ..write('enabled: $enabled, ')
          ..write('outcomeJson: $outcomeJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sessionId, enabled, outcomeJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionContinuationDto &&
          other.sessionId == this.sessionId &&
          other.enabled == this.enabled &&
          other.outcomeJson == this.outcomeJson);
}

class SessionContinuationTableCompanion
    extends UpdateCompanion<SessionContinuationDto> {
  final Value<String> sessionId;
  final Value<bool> enabled;
  final Value<String> outcomeJson;
  const SessionContinuationTableCompanion({
    this.sessionId = const Value.absent(),
    this.enabled = const Value.absent(),
    this.outcomeJson = const Value.absent(),
  });
  SessionContinuationTableCompanion.insert({
    required String sessionId,
    required bool enabled,
    required String outcomeJson,
  }) : sessionId = Value(sessionId),
       enabled = Value(enabled),
       outcomeJson = Value(outcomeJson);
  static Insertable<SessionContinuationDto> custom({
    Expression<String>? sessionId,
    Expression<bool>? enabled,
    Expression<String>? outcomeJson,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (enabled != null) 'enabled': enabled,
      if (outcomeJson != null) 'outcome_json': outcomeJson,
    });
  }

  SessionContinuationTableCompanion copyWith({
    Value<String>? sessionId,
    Value<bool>? enabled,
    Value<String>? outcomeJson,
  }) {
    return SessionContinuationTableCompanion(
      sessionId: sessionId ?? this.sessionId,
      enabled: enabled ?? this.enabled,
      outcomeJson: outcomeJson ?? this.outcomeJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (outcomeJson.present) {
      map['outcome_json'] = Variable<String>(outcomeJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionContinuationTableCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('enabled: $enabled, ')
          ..write('outcomeJson: $outcomeJson')
          ..write(')'))
        .toString();
  }
}

mixin $SideChatExchangesTableTableToColumns
    implements Insertable<SideChatExchangeDto> {
  String get id;
  String get sessionId;
  String get sideChatId;
  String get question;
  String get answer;
  String? get answerNotice;
  int get askedAt;
  int get answeredAt;
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['side_chat_id'] = Variable<String>(sideChatId);
    map['question'] = Variable<String>(question);
    map['answer'] = Variable<String>(answer);
    if (!nullToAbsent || answerNotice != null) {
      map['answer_notice'] = Variable<String>(answerNotice);
    }
    map['asked_at'] = Variable<int>(askedAt);
    map['answered_at'] = Variable<int>(answeredAt);
    return map;
  }
}

class $SideChatExchangesTableTable extends SideChatExchangesTable
    with TableInfo<$SideChatExchangesTableTable, SideChatExchangeDto> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SideChatExchangesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions_table (session_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sideChatIdMeta = const VerificationMeta(
    'sideChatId',
  );
  @override
  late final GeneratedColumn<String> sideChatId = GeneratedColumn<String>(
    'side_chat_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionMeta = const VerificationMeta(
    'question',
  );
  @override
  late final GeneratedColumn<String> question = GeneratedColumn<String>(
    'question',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answerMeta = const VerificationMeta('answer');
  @override
  late final GeneratedColumn<String> answer = GeneratedColumn<String>(
    'answer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answerNoticeMeta = const VerificationMeta(
    'answerNotice',
  );
  @override
  late final GeneratedColumn<String> answerNotice = GeneratedColumn<String>(
    'answer_notice',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _askedAtMeta = const VerificationMeta(
    'askedAt',
  );
  @override
  late final GeneratedColumn<int> askedAt = GeneratedColumn<int>(
    'asked_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answeredAtMeta = const VerificationMeta(
    'answeredAt',
  );
  @override
  late final GeneratedColumn<int> answeredAt = GeneratedColumn<int>(
    'answered_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    sideChatId,
    question,
    answer,
    answerNotice,
    askedAt,
    answeredAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'side_chat_exchanges';
  @override
  VerificationContext validateIntegrity(
    Insertable<SideChatExchangeDto> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('side_chat_id')) {
      context.handle(
        _sideChatIdMeta,
        sideChatId.isAcceptableOrUnknown(
          data['side_chat_id']!,
          _sideChatIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sideChatIdMeta);
    }
    if (data.containsKey('question')) {
      context.handle(
        _questionMeta,
        question.isAcceptableOrUnknown(data['question']!, _questionMeta),
      );
    } else if (isInserting) {
      context.missing(_questionMeta);
    }
    if (data.containsKey('answer')) {
      context.handle(
        _answerMeta,
        answer.isAcceptableOrUnknown(data['answer']!, _answerMeta),
      );
    } else if (isInserting) {
      context.missing(_answerMeta);
    }
    if (data.containsKey('answer_notice')) {
      context.handle(
        _answerNoticeMeta,
        answerNotice.isAcceptableOrUnknown(
          data['answer_notice']!,
          _answerNoticeMeta,
        ),
      );
    }
    if (data.containsKey('asked_at')) {
      context.handle(
        _askedAtMeta,
        askedAt.isAcceptableOrUnknown(data['asked_at']!, _askedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_askedAtMeta);
    }
    if (data.containsKey('answered_at')) {
      context.handle(
        _answeredAtMeta,
        answeredAt.isAcceptableOrUnknown(data['answered_at']!, _answeredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_answeredAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SideChatExchangeDto map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SideChatExchangeDto(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      sideChatId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}side_chat_id'],
      )!,
      question: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question'],
      )!,
      answer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer'],
      )!,
      answerNotice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer_notice'],
      ),
      askedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}asked_at'],
      )!,
      answeredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}answered_at'],
      )!,
    );
  }

  @override
  $SideChatExchangesTableTable createAlias(String alias) {
    return $SideChatExchangesTableTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class SideChatExchangeDto extends DataClass
    with $SideChatExchangesTableTableToColumns {
  @override
  final String id;
  @override
  final String sessionId;
  @override
  final String sideChatId;
  @override
  final String question;
  @override
  final String answer;
  @override
  final String? answerNotice;
  @override
  final int askedAt;
  @override
  final int answeredAt;
  const SideChatExchangeDto({
    required this.id,
    required this.sessionId,
    required this.sideChatId,
    required this.question,
    required this.answer,
    this.answerNotice,
    required this.askedAt,
    required this.answeredAt,
  });
  SideChatExchangesTableCompanion toCompanion(bool nullToAbsent) {
    return SideChatExchangesTableCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      sideChatId: Value(sideChatId),
      question: Value(question),
      answer: Value(answer),
      answerNotice: answerNotice == null && nullToAbsent
          ? const Value.absent()
          : Value(answerNotice),
      askedAt: Value(askedAt),
      answeredAt: Value(answeredAt),
    );
  }

  factory SideChatExchangeDto.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SideChatExchangeDto(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      sideChatId: serializer.fromJson<String>(json['sideChatId']),
      question: serializer.fromJson<String>(json['question']),
      answer: serializer.fromJson<String>(json['answer']),
      answerNotice: serializer.fromJson<String?>(json['answerNotice']),
      askedAt: serializer.fromJson<int>(json['askedAt']),
      answeredAt: serializer.fromJson<int>(json['answeredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'sideChatId': serializer.toJson<String>(sideChatId),
      'question': serializer.toJson<String>(question),
      'answer': serializer.toJson<String>(answer),
      'answerNotice': serializer.toJson<String?>(answerNotice),
      'askedAt': serializer.toJson<int>(askedAt),
      'answeredAt': serializer.toJson<int>(answeredAt),
    };
  }

  SideChatExchangeDto copyWith({
    String? id,
    String? sessionId,
    String? sideChatId,
    String? question,
    String? answer,
    Value<String?> answerNotice = const Value.absent(),
    int? askedAt,
    int? answeredAt,
  }) => SideChatExchangeDto(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    sideChatId: sideChatId ?? this.sideChatId,
    question: question ?? this.question,
    answer: answer ?? this.answer,
    answerNotice: answerNotice.present ? answerNotice.value : this.answerNotice,
    askedAt: askedAt ?? this.askedAt,
    answeredAt: answeredAt ?? this.answeredAt,
  );
  SideChatExchangeDto copyWithCompanion(SideChatExchangesTableCompanion data) {
    return SideChatExchangeDto(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      sideChatId: data.sideChatId.present
          ? data.sideChatId.value
          : this.sideChatId,
      question: data.question.present ? data.question.value : this.question,
      answer: data.answer.present ? data.answer.value : this.answer,
      answerNotice: data.answerNotice.present
          ? data.answerNotice.value
          : this.answerNotice,
      askedAt: data.askedAt.present ? data.askedAt.value : this.askedAt,
      answeredAt: data.answeredAt.present
          ? data.answeredAt.value
          : this.answeredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SideChatExchangeDto(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('sideChatId: $sideChatId, ')
          ..write('question: $question, ')
          ..write('answer: $answer, ')
          ..write('answerNotice: $answerNotice, ')
          ..write('askedAt: $askedAt, ')
          ..write('answeredAt: $answeredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    sideChatId,
    question,
    answer,
    answerNotice,
    askedAt,
    answeredAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SideChatExchangeDto &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.sideChatId == this.sideChatId &&
          other.question == this.question &&
          other.answer == this.answer &&
          other.answerNotice == this.answerNotice &&
          other.askedAt == this.askedAt &&
          other.answeredAt == this.answeredAt);
}

class SideChatExchangesTableCompanion
    extends UpdateCompanion<SideChatExchangeDto> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> sideChatId;
  final Value<String> question;
  final Value<String> answer;
  final Value<String?> answerNotice;
  final Value<int> askedAt;
  final Value<int> answeredAt;
  const SideChatExchangesTableCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.sideChatId = const Value.absent(),
    this.question = const Value.absent(),
    this.answer = const Value.absent(),
    this.answerNotice = const Value.absent(),
    this.askedAt = const Value.absent(),
    this.answeredAt = const Value.absent(),
  });
  SideChatExchangesTableCompanion.insert({
    required String id,
    required String sessionId,
    required String sideChatId,
    required String question,
    required String answer,
    this.answerNotice = const Value.absent(),
    required int askedAt,
    required int answeredAt,
  }) : id = Value(id),
       sessionId = Value(sessionId),
       sideChatId = Value(sideChatId),
       question = Value(question),
       answer = Value(answer),
       askedAt = Value(askedAt),
       answeredAt = Value(answeredAt);
  static Insertable<SideChatExchangeDto> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? sideChatId,
    Expression<String>? question,
    Expression<String>? answer,
    Expression<String>? answerNotice,
    Expression<int>? askedAt,
    Expression<int>? answeredAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (sideChatId != null) 'side_chat_id': sideChatId,
      if (question != null) 'question': question,
      if (answer != null) 'answer': answer,
      if (answerNotice != null) 'answer_notice': answerNotice,
      if (askedAt != null) 'asked_at': askedAt,
      if (answeredAt != null) 'answered_at': answeredAt,
    });
  }

  SideChatExchangesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? sideChatId,
    Value<String>? question,
    Value<String>? answer,
    Value<String?>? answerNotice,
    Value<int>? askedAt,
    Value<int>? answeredAt,
  }) {
    return SideChatExchangesTableCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      sideChatId: sideChatId ?? this.sideChatId,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      answerNotice: answerNotice ?? this.answerNotice,
      askedAt: askedAt ?? this.askedAt,
      answeredAt: answeredAt ?? this.answeredAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (sideChatId.present) {
      map['side_chat_id'] = Variable<String>(sideChatId.value);
    }
    if (question.present) {
      map['question'] = Variable<String>(question.value);
    }
    if (answer.present) {
      map['answer'] = Variable<String>(answer.value);
    }
    if (answerNotice.present) {
      map['answer_notice'] = Variable<String>(answerNotice.value);
    }
    if (askedAt.present) {
      map['asked_at'] = Variable<int>(askedAt.value);
    }
    if (answeredAt.present) {
      map['answered_at'] = Variable<int>(answeredAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SideChatExchangesTableCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('sideChatId: $sideChatId, ')
          ..write('question: $question, ')
          ..write('answer: $answer, ')
          ..write('answerNotice: $answerNotice, ')
          ..write('askedAt: $askedAt, ')
          ..write('answeredAt: $answeredAt')
          ..write(')'))
        .toString();
  }
}

mixin $ScheduledTaskRunsTableTableToColumns
    implements Insertable<ScheduledTaskRunDto> {
  String get id;
  String get taskId;

  /// The session a started run sent its prompt to. Null for other outcomes,
  /// and once that session is deleted.
  String? get sessionId;

  /// UTC milliseconds of the occurrence, or of the Run now tap.
  int get scheduledFor;

  /// The task zone's offset at [scheduledFor], frozen when written so a later
  /// zone edit keeps past rows.
  int get scheduledForOffsetMinutes;
  int get firedAt;
  ScheduledTaskRunOutcomeKind get outcome;

  /// Set only for a failed run.
  TaskRunFailureReason? get reason;

  /// Set only for a started run.
  bool get late;

  /// When the user first sent their own prompt into the run's session.
  int? get userPromptedAt;

  /// When the bridge asked the run's session to compact.
  int? get compactRequestedAt;
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    map['scheduled_for'] = Variable<int>(scheduledFor);
    map['scheduled_for_offset_minutes'] = Variable<int>(
      scheduledForOffsetMinutes,
    );
    map['fired_at'] = Variable<int>(firedAt);
    {
      map['outcome'] = Variable<String>(
        $ScheduledTaskRunsTableTable.$converteroutcome.toSql(outcome),
      );
    }
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(
        $ScheduledTaskRunsTableTable.$converterreasonn.toSql(reason),
      );
    }
    map['late'] = Variable<bool>(late);
    if (!nullToAbsent || userPromptedAt != null) {
      map['user_prompted_at'] = Variable<int>(userPromptedAt);
    }
    if (!nullToAbsent || compactRequestedAt != null) {
      map['compact_requested_at'] = Variable<int>(compactRequestedAt);
    }
    return map;
  }
}

class $ScheduledTaskRunsTableTable extends ScheduledTaskRunsTable
    with TableInfo<$ScheduledTaskRunsTableTable, ScheduledTaskRunDto> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScheduledTaskRunsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES scheduled_tasks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions_table (session_id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _scheduledForMeta = const VerificationMeta(
    'scheduledFor',
  );
  @override
  late final GeneratedColumn<int> scheduledFor = GeneratedColumn<int>(
    'scheduled_for',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduledForOffsetMinutesMeta =
      const VerificationMeta('scheduledForOffsetMinutes');
  @override
  late final GeneratedColumn<int> scheduledForOffsetMinutes =
      GeneratedColumn<int>(
        'scheduled_for_offset_minutes',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _firedAtMeta = const VerificationMeta(
    'firedAt',
  );
  @override
  late final GeneratedColumn<int> firedAt = GeneratedColumn<int>(
    'fired_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<
    ScheduledTaskRunOutcomeKind,
    String
  >
  outcome =
      GeneratedColumn<String>(
        'outcome',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ScheduledTaskRunOutcomeKind>(
        $ScheduledTaskRunsTableTable.$converteroutcome,
      );
  @override
  late final GeneratedColumnWithTypeConverter<TaskRunFailureReason?, String>
  reason =
      GeneratedColumn<String>(
        'reason',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<TaskRunFailureReason?>(
        $ScheduledTaskRunsTableTable.$converterreasonn,
      );
  static const VerificationMeta _lateMeta = const VerificationMeta('late');
  @override
  late final GeneratedColumn<bool> late = GeneratedColumn<bool>(
    'late',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("late" IN (0, 1))',
    ),
  );
  static const VerificationMeta _userPromptedAtMeta = const VerificationMeta(
    'userPromptedAt',
  );
  @override
  late final GeneratedColumn<int> userPromptedAt = GeneratedColumn<int>(
    'user_prompted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _compactRequestedAtMeta =
      const VerificationMeta('compactRequestedAt');
  @override
  late final GeneratedColumn<int> compactRequestedAt = GeneratedColumn<int>(
    'compact_requested_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    sessionId,
    scheduledFor,
    scheduledForOffsetMinutes,
    firedAt,
    outcome,
    reason,
    late,
    userPromptedAt,
    compactRequestedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scheduled_task_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScheduledTaskRunDto> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('scheduled_for')) {
      context.handle(
        _scheduledForMeta,
        scheduledFor.isAcceptableOrUnknown(
          data['scheduled_for']!,
          _scheduledForMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledForMeta);
    }
    if (data.containsKey('scheduled_for_offset_minutes')) {
      context.handle(
        _scheduledForOffsetMinutesMeta,
        scheduledForOffsetMinutes.isAcceptableOrUnknown(
          data['scheduled_for_offset_minutes']!,
          _scheduledForOffsetMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledForOffsetMinutesMeta);
    }
    if (data.containsKey('fired_at')) {
      context.handle(
        _firedAtMeta,
        firedAt.isAcceptableOrUnknown(data['fired_at']!, _firedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_firedAtMeta);
    }
    if (data.containsKey('late')) {
      context.handle(
        _lateMeta,
        late.isAcceptableOrUnknown(data['late']!, _lateMeta),
      );
    } else if (isInserting) {
      context.missing(_lateMeta);
    }
    if (data.containsKey('user_prompted_at')) {
      context.handle(
        _userPromptedAtMeta,
        userPromptedAt.isAcceptableOrUnknown(
          data['user_prompted_at']!,
          _userPromptedAtMeta,
        ),
      );
    }
    if (data.containsKey('compact_requested_at')) {
      context.handle(
        _compactRequestedAtMeta,
        compactRequestedAt.isAcceptableOrUnknown(
          data['compact_requested_at']!,
          _compactRequestedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScheduledTaskRunDto map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduledTaskRunDto(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      ),
      scheduledFor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scheduled_for'],
      )!,
      scheduledForOffsetMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scheduled_for_offset_minutes'],
      )!,
      firedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fired_at'],
      )!,
      outcome: $ScheduledTaskRunsTableTable.$converteroutcome.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}outcome'],
        )!,
      ),
      reason: $ScheduledTaskRunsTableTable.$converterreasonn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}reason'],
        ),
      ),
      late: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}late'],
      )!,
      userPromptedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_prompted_at'],
      ),
      compactRequestedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}compact_requested_at'],
      ),
    );
  }

  @override
  $ScheduledTaskRunsTableTable createAlias(String alias) {
    return $ScheduledTaskRunsTableTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ScheduledTaskRunOutcomeKind, String, String>
  $converteroutcome = const EnumNameConverter<ScheduledTaskRunOutcomeKind>(
    ScheduledTaskRunOutcomeKind.values,
  );
  static JsonTypeConverter2<TaskRunFailureReason, String, String>
  $converterreason = const EnumNameConverter<TaskRunFailureReason>(
    TaskRunFailureReason.values,
  );
  static JsonTypeConverter2<TaskRunFailureReason?, String?, String?>
  $converterreasonn = JsonTypeConverter2.asNullable($converterreason);
  @override
  bool get withoutRowId => true;
}

class ScheduledTaskRunDto extends DataClass
    with $ScheduledTaskRunsTableTableToColumns {
  @override
  final String id;
  @override
  final String taskId;

  /// The session a started run sent its prompt to. Null for other outcomes,
  /// and once that session is deleted.
  @override
  final String? sessionId;

  /// UTC milliseconds of the occurrence, or of the Run now tap.
  @override
  final int scheduledFor;

  /// The task zone's offset at [scheduledFor], frozen when written so a later
  /// zone edit keeps past rows.
  @override
  final int scheduledForOffsetMinutes;
  @override
  final int firedAt;
  @override
  final ScheduledTaskRunOutcomeKind outcome;

  /// Set only for a failed run.
  @override
  final TaskRunFailureReason? reason;

  /// Set only for a started run.
  @override
  final bool late;

  /// When the user first sent their own prompt into the run's session.
  @override
  final int? userPromptedAt;

  /// When the bridge asked the run's session to compact.
  @override
  final int? compactRequestedAt;
  const ScheduledTaskRunDto({
    required this.id,
    required this.taskId,
    this.sessionId,
    required this.scheduledFor,
    required this.scheduledForOffsetMinutes,
    required this.firedAt,
    required this.outcome,
    this.reason,
    required this.late,
    this.userPromptedAt,
    this.compactRequestedAt,
  });
  ScheduledTaskRunsTableCompanion toCompanion(bool nullToAbsent) {
    return ScheduledTaskRunsTableCompanion(
      id: Value(id),
      taskId: Value(taskId),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      scheduledFor: Value(scheduledFor),
      scheduledForOffsetMinutes: Value(scheduledForOffsetMinutes),
      firedAt: Value(firedAt),
      outcome: Value(outcome),
      reason: reason == null && nullToAbsent
          ? const Value.absent()
          : Value(reason),
      late: Value(late),
      userPromptedAt: userPromptedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(userPromptedAt),
      compactRequestedAt: compactRequestedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(compactRequestedAt),
    );
  }

  factory ScheduledTaskRunDto.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduledTaskRunDto(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      sessionId: serializer.fromJson<String?>(json['sessionId']),
      scheduledFor: serializer.fromJson<int>(json['scheduledFor']),
      scheduledForOffsetMinutes: serializer.fromJson<int>(
        json['scheduledForOffsetMinutes'],
      ),
      firedAt: serializer.fromJson<int>(json['firedAt']),
      outcome: $ScheduledTaskRunsTableTable.$converteroutcome.fromJson(
        serializer.fromJson<String>(json['outcome']),
      ),
      reason: $ScheduledTaskRunsTableTable.$converterreasonn.fromJson(
        serializer.fromJson<String?>(json['reason']),
      ),
      late: serializer.fromJson<bool>(json['late']),
      userPromptedAt: serializer.fromJson<int?>(json['userPromptedAt']),
      compactRequestedAt: serializer.fromJson<int?>(json['compactRequestedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String>(taskId),
      'sessionId': serializer.toJson<String?>(sessionId),
      'scheduledFor': serializer.toJson<int>(scheduledFor),
      'scheduledForOffsetMinutes': serializer.toJson<int>(
        scheduledForOffsetMinutes,
      ),
      'firedAt': serializer.toJson<int>(firedAt),
      'outcome': serializer.toJson<String>(
        $ScheduledTaskRunsTableTable.$converteroutcome.toJson(outcome),
      ),
      'reason': serializer.toJson<String?>(
        $ScheduledTaskRunsTableTable.$converterreasonn.toJson(reason),
      ),
      'late': serializer.toJson<bool>(late),
      'userPromptedAt': serializer.toJson<int?>(userPromptedAt),
      'compactRequestedAt': serializer.toJson<int?>(compactRequestedAt),
    };
  }

  ScheduledTaskRunDto copyWith({
    String? id,
    String? taskId,
    Value<String?> sessionId = const Value.absent(),
    int? scheduledFor,
    int? scheduledForOffsetMinutes,
    int? firedAt,
    ScheduledTaskRunOutcomeKind? outcome,
    Value<TaskRunFailureReason?> reason = const Value.absent(),
    bool? late,
    Value<int?> userPromptedAt = const Value.absent(),
    Value<int?> compactRequestedAt = const Value.absent(),
  }) => ScheduledTaskRunDto(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    scheduledFor: scheduledFor ?? this.scheduledFor,
    scheduledForOffsetMinutes:
        scheduledForOffsetMinutes ?? this.scheduledForOffsetMinutes,
    firedAt: firedAt ?? this.firedAt,
    outcome: outcome ?? this.outcome,
    reason: reason.present ? reason.value : this.reason,
    late: late ?? this.late,
    userPromptedAt: userPromptedAt.present
        ? userPromptedAt.value
        : this.userPromptedAt,
    compactRequestedAt: compactRequestedAt.present
        ? compactRequestedAt.value
        : this.compactRequestedAt,
  );
  ScheduledTaskRunDto copyWithCompanion(ScheduledTaskRunsTableCompanion data) {
    return ScheduledTaskRunDto(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      scheduledFor: data.scheduledFor.present
          ? data.scheduledFor.value
          : this.scheduledFor,
      scheduledForOffsetMinutes: data.scheduledForOffsetMinutes.present
          ? data.scheduledForOffsetMinutes.value
          : this.scheduledForOffsetMinutes,
      firedAt: data.firedAt.present ? data.firedAt.value : this.firedAt,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      reason: data.reason.present ? data.reason.value : this.reason,
      late: data.late.present ? data.late.value : this.late,
      userPromptedAt: data.userPromptedAt.present
          ? data.userPromptedAt.value
          : this.userPromptedAt,
      compactRequestedAt: data.compactRequestedAt.present
          ? data.compactRequestedAt.value
          : this.compactRequestedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledTaskRunDto(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('sessionId: $sessionId, ')
          ..write('scheduledFor: $scheduledFor, ')
          ..write('scheduledForOffsetMinutes: $scheduledForOffsetMinutes, ')
          ..write('firedAt: $firedAt, ')
          ..write('outcome: $outcome, ')
          ..write('reason: $reason, ')
          ..write('late: $late, ')
          ..write('userPromptedAt: $userPromptedAt, ')
          ..write('compactRequestedAt: $compactRequestedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    sessionId,
    scheduledFor,
    scheduledForOffsetMinutes,
    firedAt,
    outcome,
    reason,
    late,
    userPromptedAt,
    compactRequestedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduledTaskRunDto &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.sessionId == this.sessionId &&
          other.scheduledFor == this.scheduledFor &&
          other.scheduledForOffsetMinutes == this.scheduledForOffsetMinutes &&
          other.firedAt == this.firedAt &&
          other.outcome == this.outcome &&
          other.reason == this.reason &&
          other.late == this.late &&
          other.userPromptedAt == this.userPromptedAt &&
          other.compactRequestedAt == this.compactRequestedAt);
}

class ScheduledTaskRunsTableCompanion
    extends UpdateCompanion<ScheduledTaskRunDto> {
  final Value<String> id;
  final Value<String> taskId;
  final Value<String?> sessionId;
  final Value<int> scheduledFor;
  final Value<int> scheduledForOffsetMinutes;
  final Value<int> firedAt;
  final Value<ScheduledTaskRunOutcomeKind> outcome;
  final Value<TaskRunFailureReason?> reason;
  final Value<bool> late;
  final Value<int?> userPromptedAt;
  final Value<int?> compactRequestedAt;
  const ScheduledTaskRunsTableCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.scheduledFor = const Value.absent(),
    this.scheduledForOffsetMinutes = const Value.absent(),
    this.firedAt = const Value.absent(),
    this.outcome = const Value.absent(),
    this.reason = const Value.absent(),
    this.late = const Value.absent(),
    this.userPromptedAt = const Value.absent(),
    this.compactRequestedAt = const Value.absent(),
  });
  ScheduledTaskRunsTableCompanion.insert({
    required String id,
    required String taskId,
    this.sessionId = const Value.absent(),
    required int scheduledFor,
    required int scheduledForOffsetMinutes,
    required int firedAt,
    required ScheduledTaskRunOutcomeKind outcome,
    this.reason = const Value.absent(),
    required bool late,
    this.userPromptedAt = const Value.absent(),
    this.compactRequestedAt = const Value.absent(),
  }) : id = Value(id),
       taskId = Value(taskId),
       scheduledFor = Value(scheduledFor),
       scheduledForOffsetMinutes = Value(scheduledForOffsetMinutes),
       firedAt = Value(firedAt),
       outcome = Value(outcome),
       late = Value(late);
  static Insertable<ScheduledTaskRunDto> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<String>? sessionId,
    Expression<int>? scheduledFor,
    Expression<int>? scheduledForOffsetMinutes,
    Expression<int>? firedAt,
    Expression<String>? outcome,
    Expression<String>? reason,
    Expression<bool>? late,
    Expression<int>? userPromptedAt,
    Expression<int>? compactRequestedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (sessionId != null) 'session_id': sessionId,
      if (scheduledFor != null) 'scheduled_for': scheduledFor,
      if (scheduledForOffsetMinutes != null)
        'scheduled_for_offset_minutes': scheduledForOffsetMinutes,
      if (firedAt != null) 'fired_at': firedAt,
      if (outcome != null) 'outcome': outcome,
      if (reason != null) 'reason': reason,
      if (late != null) 'late': late,
      if (userPromptedAt != null) 'user_prompted_at': userPromptedAt,
      if (compactRequestedAt != null)
        'compact_requested_at': compactRequestedAt,
    });
  }

  ScheduledTaskRunsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? taskId,
    Value<String?>? sessionId,
    Value<int>? scheduledFor,
    Value<int>? scheduledForOffsetMinutes,
    Value<int>? firedAt,
    Value<ScheduledTaskRunOutcomeKind>? outcome,
    Value<TaskRunFailureReason?>? reason,
    Value<bool>? late,
    Value<int?>? userPromptedAt,
    Value<int?>? compactRequestedAt,
  }) {
    return ScheduledTaskRunsTableCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      sessionId: sessionId ?? this.sessionId,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      scheduledForOffsetMinutes:
          scheduledForOffsetMinutes ?? this.scheduledForOffsetMinutes,
      firedAt: firedAt ?? this.firedAt,
      outcome: outcome ?? this.outcome,
      reason: reason ?? this.reason,
      late: late ?? this.late,
      userPromptedAt: userPromptedAt ?? this.userPromptedAt,
      compactRequestedAt: compactRequestedAt ?? this.compactRequestedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (scheduledFor.present) {
      map['scheduled_for'] = Variable<int>(scheduledFor.value);
    }
    if (scheduledForOffsetMinutes.present) {
      map['scheduled_for_offset_minutes'] = Variable<int>(
        scheduledForOffsetMinutes.value,
      );
    }
    if (firedAt.present) {
      map['fired_at'] = Variable<int>(firedAt.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(
        $ScheduledTaskRunsTableTable.$converteroutcome.toSql(outcome.value),
      );
    }
    if (reason.present) {
      map['reason'] = Variable<String>(
        $ScheduledTaskRunsTableTable.$converterreasonn.toSql(reason.value),
      );
    }
    if (late.present) {
      map['late'] = Variable<bool>(late.value);
    }
    if (userPromptedAt.present) {
      map['user_prompted_at'] = Variable<int>(userPromptedAt.value);
    }
    if (compactRequestedAt.present) {
      map['compact_requested_at'] = Variable<int>(compactRequestedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledTaskRunsTableCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('sessionId: $sessionId, ')
          ..write('scheduledFor: $scheduledFor, ')
          ..write('scheduledForOffsetMinutes: $scheduledForOffsetMinutes, ')
          ..write('firedAt: $firedAt, ')
          ..write('outcome: $outcome, ')
          ..write('reason: $reason, ')
          ..write('late: $late, ')
          ..write('userPromptedAt: $userPromptedAt, ')
          ..write('compactRequestedAt: $compactRequestedAt')
          ..write(')'))
        .toString();
  }
}

mixin $SessionRunningTurnsTableTableToColumns
    implements Insertable<SessionRunningTurnDto> {
  String get sessionId;

  /// UTC milliseconds of when this bridge run first saw the turn running, or
  /// adopted it from an earlier run.
  int get startedAt;
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['started_at'] = Variable<int>(startedAt);
    return map;
  }
}

class $SessionRunningTurnsTableTable extends SessionRunningTurnsTable
    with TableInfo<$SessionRunningTurnsTableTable, SessionRunningTurnDto> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionRunningTurnsTableTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions_table (session_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [sessionId, startedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_running_turns';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionRunningTurnDto> instance, {
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
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  SessionRunningTurnDto map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionRunningTurnDto(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      )!,
    );
  }

  @override
  $SessionRunningTurnsTableTable createAlias(String alias) {
    return $SessionRunningTurnsTableTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class SessionRunningTurnDto extends DataClass
    with $SessionRunningTurnsTableTableToColumns {
  @override
  final String sessionId;

  /// UTC milliseconds of when this bridge run first saw the turn running, or
  /// adopted it from an earlier run.
  @override
  final int startedAt;
  const SessionRunningTurnDto({
    required this.sessionId,
    required this.startedAt,
  });
  SessionRunningTurnsTableCompanion toCompanion(bool nullToAbsent) {
    return SessionRunningTurnsTableCompanion(
      sessionId: Value(sessionId),
      startedAt: Value(startedAt),
    );
  }

  factory SessionRunningTurnDto.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionRunningTurnDto(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      startedAt: serializer.fromJson<int>(json['startedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'startedAt': serializer.toJson<int>(startedAt),
    };
  }

  SessionRunningTurnDto copyWith({String? sessionId, int? startedAt}) =>
      SessionRunningTurnDto(
        sessionId: sessionId ?? this.sessionId,
        startedAt: startedAt ?? this.startedAt,
      );
  SessionRunningTurnDto copyWithCompanion(
    SessionRunningTurnsTableCompanion data,
  ) {
    return SessionRunningTurnDto(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionRunningTurnDto(')
          ..write('sessionId: $sessionId, ')
          ..write('startedAt: $startedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sessionId, startedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionRunningTurnDto &&
          other.sessionId == this.sessionId &&
          other.startedAt == this.startedAt);
}

class SessionRunningTurnsTableCompanion
    extends UpdateCompanion<SessionRunningTurnDto> {
  final Value<String> sessionId;
  final Value<int> startedAt;
  const SessionRunningTurnsTableCompanion({
    this.sessionId = const Value.absent(),
    this.startedAt = const Value.absent(),
  });
  SessionRunningTurnsTableCompanion.insert({
    required String sessionId,
    required int startedAt,
  }) : sessionId = Value(sessionId),
       startedAt = Value(startedAt);
  static Insertable<SessionRunningTurnDto> custom({
    Expression<String>? sessionId,
    Expression<int>? startedAt,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (startedAt != null) 'started_at': startedAt,
    });
  }

  SessionRunningTurnsTableCompanion copyWith({
    Value<String>? sessionId,
    Value<int>? startedAt,
  }) {
    return SessionRunningTurnsTableCompanion(
      sessionId: sessionId ?? this.sessionId,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionRunningTurnsTableCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('startedAt: $startedAt')
          ..write(')'))
        .toString();
  }
}

mixin $SessionInterruptionsTableTableToColumns
    implements Insertable<SessionInterruptionDto> {
  String get sessionId;

  /// The newest stored history message when the interruption was recorded.
  String get afterMessageId;

  /// Whether the user opened the session or sent to it since.
  bool get acknowledged;
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['after_message_id'] = Variable<String>(afterMessageId);
    map['acknowledged'] = Variable<bool>(acknowledged);
    return map;
  }
}

class $SessionInterruptionsTableTable extends SessionInterruptionsTable
    with TableInfo<$SessionInterruptionsTableTable, SessionInterruptionDto> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionInterruptionsTableTable(this.attachedDatabase, [this._alias]);
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
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions_table (session_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _afterMessageIdMeta = const VerificationMeta(
    'afterMessageId',
  );
  @override
  late final GeneratedColumn<String> afterMessageId = GeneratedColumn<String>(
    'after_message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _acknowledgedMeta = const VerificationMeta(
    'acknowledged',
  );
  @override
  late final GeneratedColumn<bool> acknowledged = GeneratedColumn<bool>(
    'acknowledged',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("acknowledged" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    afterMessageId,
    acknowledged,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_interruptions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionInterruptionDto> instance, {
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
    if (data.containsKey('after_message_id')) {
      context.handle(
        _afterMessageIdMeta,
        afterMessageId.isAcceptableOrUnknown(
          data['after_message_id']!,
          _afterMessageIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_afterMessageIdMeta);
    }
    if (data.containsKey('acknowledged')) {
      context.handle(
        _acknowledgedMeta,
        acknowledged.isAcceptableOrUnknown(
          data['acknowledged']!,
          _acknowledgedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_acknowledgedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  SessionInterruptionDto map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionInterruptionDto(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      afterMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}after_message_id'],
      )!,
      acknowledged: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}acknowledged'],
      )!,
    );
  }

  @override
  $SessionInterruptionsTableTable createAlias(String alias) {
    return $SessionInterruptionsTableTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class SessionInterruptionDto extends DataClass
    with $SessionInterruptionsTableTableToColumns {
  @override
  final String sessionId;

  /// The newest stored history message when the interruption was recorded.
  @override
  final String afterMessageId;

  /// Whether the user opened the session or sent to it since.
  @override
  final bool acknowledged;
  const SessionInterruptionDto({
    required this.sessionId,
    required this.afterMessageId,
    required this.acknowledged,
  });
  SessionInterruptionsTableCompanion toCompanion(bool nullToAbsent) {
    return SessionInterruptionsTableCompanion(
      sessionId: Value(sessionId),
      afterMessageId: Value(afterMessageId),
      acknowledged: Value(acknowledged),
    );
  }

  factory SessionInterruptionDto.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionInterruptionDto(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      afterMessageId: serializer.fromJson<String>(json['afterMessageId']),
      acknowledged: serializer.fromJson<bool>(json['acknowledged']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'afterMessageId': serializer.toJson<String>(afterMessageId),
      'acknowledged': serializer.toJson<bool>(acknowledged),
    };
  }

  SessionInterruptionDto copyWith({
    String? sessionId,
    String? afterMessageId,
    bool? acknowledged,
  }) => SessionInterruptionDto(
    sessionId: sessionId ?? this.sessionId,
    afterMessageId: afterMessageId ?? this.afterMessageId,
    acknowledged: acknowledged ?? this.acknowledged,
  );
  SessionInterruptionDto copyWithCompanion(
    SessionInterruptionsTableCompanion data,
  ) {
    return SessionInterruptionDto(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      afterMessageId: data.afterMessageId.present
          ? data.afterMessageId.value
          : this.afterMessageId,
      acknowledged: data.acknowledged.present
          ? data.acknowledged.value
          : this.acknowledged,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionInterruptionDto(')
          ..write('sessionId: $sessionId, ')
          ..write('afterMessageId: $afterMessageId, ')
          ..write('acknowledged: $acknowledged')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sessionId, afterMessageId, acknowledged);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionInterruptionDto &&
          other.sessionId == this.sessionId &&
          other.afterMessageId == this.afterMessageId &&
          other.acknowledged == this.acknowledged);
}

class SessionInterruptionsTableCompanion
    extends UpdateCompanion<SessionInterruptionDto> {
  final Value<String> sessionId;
  final Value<String> afterMessageId;
  final Value<bool> acknowledged;
  const SessionInterruptionsTableCompanion({
    this.sessionId = const Value.absent(),
    this.afterMessageId = const Value.absent(),
    this.acknowledged = const Value.absent(),
  });
  SessionInterruptionsTableCompanion.insert({
    required String sessionId,
    required String afterMessageId,
    required bool acknowledged,
  }) : sessionId = Value(sessionId),
       afterMessageId = Value(afterMessageId),
       acknowledged = Value(acknowledged);
  static Insertable<SessionInterruptionDto> custom({
    Expression<String>? sessionId,
    Expression<String>? afterMessageId,
    Expression<bool>? acknowledged,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (afterMessageId != null) 'after_message_id': afterMessageId,
      if (acknowledged != null) 'acknowledged': acknowledged,
    });
  }

  SessionInterruptionsTableCompanion copyWith({
    Value<String>? sessionId,
    Value<String>? afterMessageId,
    Value<bool>? acknowledged,
  }) {
    return SessionInterruptionsTableCompanion(
      sessionId: sessionId ?? this.sessionId,
      afterMessageId: afterMessageId ?? this.afterMessageId,
      acknowledged: acknowledged ?? this.acknowledged,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (afterMessageId.present) {
      map['after_message_id'] = Variable<String>(afterMessageId.value);
    }
    if (acknowledged.present) {
      map['acknowledged'] = Variable<bool>(acknowledged.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionInterruptionsTableCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('afterMessageId: $afterMessageId, ')
          ..write('acknowledged: $acknowledged')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProjectsTableTable projectsTable = $ProjectsTableTable(this);
  late final $ScheduledTasksTableTable scheduledTasksTable =
      $ScheduledTasksTableTable(this);
  late final $SessionTableTable sessionTable = $SessionTableTable(this);
  late final $DeletedSessionsTableTable deletedSessionsTable =
      $DeletedSessionsTableTable(this);
  late final $CatalogHydrationsTableTable catalogHydrationsTable =
      $CatalogHydrationsTableTable(this);
  late final $SessionOptionsCacheTableTable sessionOptionsCacheTable =
      $SessionOptionsCacheTableTable(this);
  late final $NewSessionDefaultsTableTable newSessionDefaultsTable =
      $NewSessionDefaultsTableTable(this);
  late final $AcceptedPromptsTableTable acceptedPromptsTable =
      $AcceptedPromptsTableTable(this);
  late final $SessionContinuationTableTable sessionContinuationTable =
      $SessionContinuationTableTable(this);
  late final $SideChatExchangesTableTable sideChatExchangesTable =
      $SideChatExchangesTableTable(this);
  late final $ScheduledTaskRunsTableTable scheduledTaskRunsTable =
      $ScheduledTaskRunsTableTable(this);
  late final $SessionRunningTurnsTableTable sessionRunningTurnsTable =
      $SessionRunningTurnsTableTable(this);
  late final $SessionInterruptionsTableTable sessionInterruptionsTable =
      $SessionInterruptionsTableTable(this);
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
  late final Index idxSideChatExchangesSession = Index(
    'idx_side_chat_exchanges_session',
    'CREATE INDEX idx_side_chat_exchanges_session ON side_chat_exchanges (session_id, side_chat_id, answered_at)',
  );
  late final Index idxScheduledTasksNextDue = Index(
    'idx_scheduled_tasks_next_due',
    'CREATE INDEX idx_scheduled_tasks_next_due ON scheduled_tasks (next_due_at)',
  );
  late final Index idxScheduledTaskRunsTask = Index(
    'idx_scheduled_task_runs_task',
    'CREATE INDEX idx_scheduled_task_runs_task ON scheduled_task_runs (task_id, fired_at)',
  );
  late final Index idxScheduledTaskRunsSession = Index(
    'idx_scheduled_task_runs_session',
    'CREATE INDEX idx_scheduled_task_runs_session ON scheduled_task_runs (session_id)',
  );
  late final ProjectsDao projectsDao = ProjectsDao(this as AppDatabase);
  late final SessionDao sessionDao = SessionDao(this as AppDatabase);
  late final CatalogHydrationsDao catalogHydrationsDao = CatalogHydrationsDao(
    this as AppDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    projectsTable,
    scheduledTasksTable,
    sessionTable,
    deletedSessionsTable,
    catalogHydrationsTable,
    sessionOptionsCacheTable,
    newSessionDefaultsTable,
    acceptedPromptsTable,
    sessionContinuationTable,
    sideChatExchangesTable,
    scheduledTaskRunsTable,
    sessionRunningTurnsTable,
    sessionInterruptionsTable,
    idxProjectsUpdated,
    idxSessionsPluginBackend,
    idxSessionsRoots,
    idxSessionsChildren,
    idxSideChatExchangesSession,
    idxScheduledTasksNextDue,
    idxScheduledTaskRunsTask,
    idxScheduledTaskRunsSession,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sessions_table',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('scheduled_tasks', kind: UpdateKind.update)],
    ),
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
        'scheduled_tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('sessions_table', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sessions_table',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('session_continuations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sessions_table',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('side_chat_exchanges', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'scheduled_tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('scheduled_task_runs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sessions_table',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('scheduled_task_runs', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sessions_table',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('session_running_turns', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sessions_table',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('session_interruptions', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ProjectsTableTableCreateCompanionBuilder =
    ProjectsTableCompanion Function({
      required String projectId,
      required String path,
      Value<bool> hidden,
      Value<String?> baseBranch,
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
          PrefetchHooks Function({bool sessionTableRefs})
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
                Value<String?> displayName = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> projectionUpdatedAt = const Value.absent(),
              }) => ProjectsTableCompanion(
                projectId: projectId,
                path: path,
                hidden: hidden,
                baseBranch: baseBranch,
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
                Value<String?> displayName = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                required int projectionUpdatedAt,
              }) => ProjectsTableCompanion.insert(
                projectId: projectId,
                path: path,
                hidden: hidden,
                baseBranch: baseBranch,
                displayName: displayName,
                createdAt: createdAt,
                updatedAt: updatedAt,
                projectionUpdatedAt: projectionUpdatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProjectsTableTable, ProjectDto>(table),
                  $$ProjectsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (sessionTableRefs) db.sessionTable],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sessionTableRefs)
                    await $_getPrefetchedDataByColumns<
                      ProjectDto,
                      $ProjectsTableTable,
                      SessionDto,
                      $SessionTableTable
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
                      currentColumn: 'project_id',
                      referencedColumn: 'project_id',
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
      PrefetchHooks Function({bool sessionTableRefs})
    >;
typedef $$ScheduledTasksTableTableCreateCompanionBuilder =
    ScheduledTasksTableCompanion Function({
      required String id,
      required String name,
      required String promptJson,
      required String projectId,
      required String pluginId,
      Value<String?> agent,
      Value<String?> modelJson,
      Value<String?> variant,
      required bool fastMode,
      required bool dedicatedWorktree,
      required String scheduleJson,
      required String timeZone,
      required TaskMissedRunPolicy missedRunPolicy,
      required ScheduledTaskRunModeKind runMode,
      required bool autoCompact,
      required TaskApprovalMode approvalMode,
      required bool enabled,
      Value<int?> nextDueAt,
      Value<String?> targetSessionId,
      Value<int?> completedAt,
      required int createdAt,
      required int updatedAt,
    });
typedef $$ScheduledTasksTableTableUpdateCompanionBuilder =
    ScheduledTasksTableCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> promptJson,
      Value<String> projectId,
      Value<String> pluginId,
      Value<String?> agent,
      Value<String?> modelJson,
      Value<String?> variant,
      Value<bool> fastMode,
      Value<bool> dedicatedWorktree,
      Value<String> scheduleJson,
      Value<String> timeZone,
      Value<TaskMissedRunPolicy> missedRunPolicy,
      Value<ScheduledTaskRunModeKind> runMode,
      Value<bool> autoCompact,
      Value<TaskApprovalMode> approvalMode,
      Value<bool> enabled,
      Value<int?> nextDueAt,
      Value<String?> targetSessionId,
      Value<int?> completedAt,
      Value<int> createdAt,
      Value<int> updatedAt,
    });

final class $$ScheduledTasksTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ScheduledTasksTableTable,
          ScheduledTaskDto
        > {
  $$ScheduledTasksTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SessionTableTable _targetSessionIdTable(_$AppDatabase db) =>
      db.sessionTable.createAlias(
        'scheduled_tasks__target_session_id__sessions_table__session_id',
      );

  $$SessionTableTableProcessedTableManager? get targetSessionId {
    final $_column = $_itemColumn<String>('target_session_id');
    if ($_column == null) return null;
    final manager = $$SessionTableTableTableManager(
      $_db,
      $_db.sessionTable,
    ).filter((f) => f.sessionId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_targetSessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SessionTableTable, List<SessionDto>>
  _sessionTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sessionTable,
    aliasName: 'scheduled_tasks__id__sessions_table__scheduled_task_id',
  );

  $$SessionTableTableProcessedTableManager get sessionTableRefs {
    final manager = $$SessionTableTableTableManager($_db, $_db.sessionTable)
        .filter(
          (f) => f.scheduledTaskId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(_sessionTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ScheduledTaskRunsTableTable,
    List<ScheduledTaskRunDto>
  >
  _scheduledTaskRunsTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.scheduledTaskRunsTable,
        aliasName: 'scheduled_tasks__id__scheduled_task_runs__task_id',
      );

  $$ScheduledTaskRunsTableTableProcessedTableManager
  get scheduledTaskRunsTableRefs {
    final manager = $$ScheduledTaskRunsTableTableTableManager(
      $_db,
      $_db.scheduledTaskRunsTable,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _scheduledTaskRunsTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ScheduledTasksTableTableFilterComposer
    extends Composer<_$AppDatabase, $ScheduledTasksTableTable> {
  $$ScheduledTasksTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get promptJson => $composableBuilder(
    column: $table.promptJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pluginId => $composableBuilder(
    column: $table.pluginId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get agent => $composableBuilder(
    column: $table.agent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelJson => $composableBuilder(
    column: $table.modelJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get variant => $composableBuilder(
    column: $table.variant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get fastMode => $composableBuilder(
    column: $table.fastMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dedicatedWorktree => $composableBuilder(
    column: $table.dedicatedWorktree,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduleJson => $composableBuilder(
    column: $table.scheduleJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    TaskMissedRunPolicy,
    TaskMissedRunPolicy,
    String
  >
  get missedRunPolicy => $composableBuilder(
    column: $table.missedRunPolicy,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<
    ScheduledTaskRunModeKind,
    ScheduledTaskRunModeKind,
    String
  >
  get runMode => $composableBuilder(
    column: $table.runMode,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get autoCompact => $composableBuilder(
    column: $table.autoCompact,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TaskApprovalMode, TaskApprovalMode, String>
  get approvalMode => $composableBuilder(
    column: $table.approvalMode,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextDueAt => $composableBuilder(
    column: $table.nextDueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
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

  $$SessionTableTableFilterComposer get targetSessionId {
    final $$SessionTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetSessionId,
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

  Expression<bool> sessionTableRefs(
    Expression<bool> Function($$SessionTableTableFilterComposer f) f,
  ) {
    final $$SessionTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessionTable,
      getReferencedColumn: (t) => t.scheduledTaskId,
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

  Expression<bool> scheduledTaskRunsTableRefs(
    Expression<bool> Function($$ScheduledTaskRunsTableTableFilterComposer f) f,
  ) {
    final $$ScheduledTaskRunsTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.scheduledTaskRunsTable,
          getReferencedColumn: (t) => t.taskId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledTaskRunsTableTableFilterComposer(
                $db: $db,
                $table: $db.scheduledTaskRunsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ScheduledTasksTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ScheduledTasksTableTable> {
  $$ScheduledTasksTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get promptJson => $composableBuilder(
    column: $table.promptJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pluginId => $composableBuilder(
    column: $table.pluginId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get agent => $composableBuilder(
    column: $table.agent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelJson => $composableBuilder(
    column: $table.modelJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get variant => $composableBuilder(
    column: $table.variant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get fastMode => $composableBuilder(
    column: $table.fastMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dedicatedWorktree => $composableBuilder(
    column: $table.dedicatedWorktree,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduleJson => $composableBuilder(
    column: $table.scheduleJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeZone => $composableBuilder(
    column: $table.timeZone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get missedRunPolicy => $composableBuilder(
    column: $table.missedRunPolicy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runMode => $composableBuilder(
    column: $table.runMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoCompact => $composableBuilder(
    column: $table.autoCompact,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get approvalMode => $composableBuilder(
    column: $table.approvalMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextDueAt => $composableBuilder(
    column: $table.nextDueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
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

  $$SessionTableTableOrderingComposer get targetSessionId {
    final $$SessionTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetSessionId,
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

class $$ScheduledTasksTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScheduledTasksTableTable> {
  $$ScheduledTasksTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get promptJson => $composableBuilder(
    column: $table.promptJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get pluginId =>
      $composableBuilder(column: $table.pluginId, builder: (column) => column);

  GeneratedColumn<String> get agent =>
      $composableBuilder(column: $table.agent, builder: (column) => column);

  GeneratedColumn<String> get modelJson =>
      $composableBuilder(column: $table.modelJson, builder: (column) => column);

  GeneratedColumn<String> get variant =>
      $composableBuilder(column: $table.variant, builder: (column) => column);

  GeneratedColumn<bool> get fastMode =>
      $composableBuilder(column: $table.fastMode, builder: (column) => column);

  GeneratedColumn<bool> get dedicatedWorktree => $composableBuilder(
    column: $table.dedicatedWorktree,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scheduleJson => $composableBuilder(
    column: $table.scheduleJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timeZone =>
      $composableBuilder(column: $table.timeZone, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TaskMissedRunPolicy, String>
  get missedRunPolicy => $composableBuilder(
    column: $table.missedRunPolicy,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<ScheduledTaskRunModeKind, String>
  get runMode =>
      $composableBuilder(column: $table.runMode, builder: (column) => column);

  GeneratedColumn<bool> get autoCompact => $composableBuilder(
    column: $table.autoCompact,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<TaskApprovalMode, String> get approvalMode =>
      $composableBuilder(
        column: $table.approvalMode,
        builder: (column) => column,
      );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get nextDueAt =>
      $composableBuilder(column: $table.nextDueAt, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$SessionTableTableAnnotationComposer get targetSessionId {
    final $$SessionTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetSessionId,
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

  Expression<T> sessionTableRefs<T extends Object>(
    Expression<T> Function($$SessionTableTableAnnotationComposer a) f,
  ) {
    final $$SessionTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessionTable,
      getReferencedColumn: (t) => t.scheduledTaskId,
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

  Expression<T> scheduledTaskRunsTableRefs<T extends Object>(
    Expression<T> Function($$ScheduledTaskRunsTableTableAnnotationComposer a) f,
  ) {
    final $$ScheduledTaskRunsTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.scheduledTaskRunsTable,
          getReferencedColumn: (t) => t.taskId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledTaskRunsTableTableAnnotationComposer(
                $db: $db,
                $table: $db.scheduledTaskRunsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ScheduledTasksTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScheduledTasksTableTable,
          ScheduledTaskDto,
          $$ScheduledTasksTableTableFilterComposer,
          $$ScheduledTasksTableTableOrderingComposer,
          $$ScheduledTasksTableTableAnnotationComposer,
          $$ScheduledTasksTableTableCreateCompanionBuilder,
          $$ScheduledTasksTableTableUpdateCompanionBuilder,
          (ScheduledTaskDto, $$ScheduledTasksTableTableReferences),
          ScheduledTaskDto,
          PrefetchHooks Function({
            bool targetSessionId,
            bool sessionTableRefs,
            bool scheduledTaskRunsTableRefs,
          })
        > {
  $$ScheduledTasksTableTableTableManager(
    _$AppDatabase db,
    $ScheduledTasksTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScheduledTasksTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScheduledTasksTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ScheduledTasksTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> promptJson = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> pluginId = const Value.absent(),
                Value<String?> agent = const Value.absent(),
                Value<String?> modelJson = const Value.absent(),
                Value<String?> variant = const Value.absent(),
                Value<bool> fastMode = const Value.absent(),
                Value<bool> dedicatedWorktree = const Value.absent(),
                Value<String> scheduleJson = const Value.absent(),
                Value<String> timeZone = const Value.absent(),
                Value<TaskMissedRunPolicy> missedRunPolicy =
                    const Value.absent(),
                Value<ScheduledTaskRunModeKind> runMode = const Value.absent(),
                Value<bool> autoCompact = const Value.absent(),
                Value<TaskApprovalMode> approvalMode = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int?> nextDueAt = const Value.absent(),
                Value<String?> targetSessionId = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => ScheduledTasksTableCompanion(
                id: id,
                name: name,
                promptJson: promptJson,
                projectId: projectId,
                pluginId: pluginId,
                agent: agent,
                modelJson: modelJson,
                variant: variant,
                fastMode: fastMode,
                dedicatedWorktree: dedicatedWorktree,
                scheduleJson: scheduleJson,
                timeZone: timeZone,
                missedRunPolicy: missedRunPolicy,
                runMode: runMode,
                autoCompact: autoCompact,
                approvalMode: approvalMode,
                enabled: enabled,
                nextDueAt: nextDueAt,
                targetSessionId: targetSessionId,
                completedAt: completedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String promptJson,
                required String projectId,
                required String pluginId,
                Value<String?> agent = const Value.absent(),
                Value<String?> modelJson = const Value.absent(),
                Value<String?> variant = const Value.absent(),
                required bool fastMode,
                required bool dedicatedWorktree,
                required String scheduleJson,
                required String timeZone,
                required TaskMissedRunPolicy missedRunPolicy,
                required ScheduledTaskRunModeKind runMode,
                required bool autoCompact,
                required TaskApprovalMode approvalMode,
                required bool enabled,
                Value<int?> nextDueAt = const Value.absent(),
                Value<String?> targetSessionId = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                required int createdAt,
                required int updatedAt,
              }) => ScheduledTasksTableCompanion.insert(
                id: id,
                name: name,
                promptJson: promptJson,
                projectId: projectId,
                pluginId: pluginId,
                agent: agent,
                modelJson: modelJson,
                variant: variant,
                fastMode: fastMode,
                dedicatedWorktree: dedicatedWorktree,
                scheduleJson: scheduleJson,
                timeZone: timeZone,
                missedRunPolicy: missedRunPolicy,
                runMode: runMode,
                autoCompact: autoCompact,
                approvalMode: approvalMode,
                enabled: enabled,
                nextDueAt: nextDueAt,
                targetSessionId: targetSessionId,
                completedAt: completedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ScheduledTasksTableTable, ScheduledTaskDto>(
                    table,
                  ),
                  $$ScheduledTasksTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                targetSessionId = false,
                sessionTableRefs = false,
                scheduledTaskRunsTableRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (sessionTableRefs) db.sessionTable,
                    if (scheduledTaskRunsTableRefs) db.scheduledTaskRunsTable,
                  ],
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
                        if (targetSessionId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.targetSessionId,
                            referencedTable:
                                $$ScheduledTasksTableTableReferences
                                    ._targetSessionIdTable(db),
                            referencedColumn:
                                $$ScheduledTasksTableTableReferences
                                    ._targetSessionIdTable(db)
                                    .sessionId,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (sessionTableRefs)
                        await $_getPrefetchedDataByColumns<
                          ScheduledTaskDto,
                          $ScheduledTasksTableTable,
                          SessionDto,
                          $SessionTableTable
                        >(
                          currentTable: table,
                          referencedTable: $$ScheduledTasksTableTableReferences
                              ._sessionTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ScheduledTasksTableTableReferences(
                                db,
                                table,
                                p0,
                              ).sessionTableRefs,
                          currentColumn: 'id',
                          referencedColumn: 'scheduled_task_id',
                          typedResults: items,
                        ),
                      if (scheduledTaskRunsTableRefs)
                        await $_getPrefetchedDataByColumns<
                          ScheduledTaskDto,
                          $ScheduledTasksTableTable,
                          ScheduledTaskRunDto,
                          $ScheduledTaskRunsTableTable
                        >(
                          currentTable: table,
                          referencedTable: $$ScheduledTasksTableTableReferences
                              ._scheduledTaskRunsTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ScheduledTasksTableTableReferences(
                                db,
                                table,
                                p0,
                              ).scheduledTaskRunsTableRefs,
                          currentColumn: 'id',
                          referencedColumn: 'task_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ScheduledTasksTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScheduledTasksTableTable,
      ScheduledTaskDto,
      $$ScheduledTasksTableTableFilterComposer,
      $$ScheduledTasksTableTableOrderingComposer,
      $$ScheduledTasksTableTableAnnotationComposer,
      $$ScheduledTasksTableTableCreateCompanionBuilder,
      $$ScheduledTasksTableTableUpdateCompanionBuilder,
      (ScheduledTaskDto, $$ScheduledTasksTableTableReferences),
      ScheduledTaskDto,
      PrefetchHooks Function({
        bool targetSessionId,
        bool sessionTableRefs,
        bool scheduledTaskRunsTableRefs,
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
      Value<bool> fastMode,
      required int createdAt,
      required int updatedAt,
      required int projectionUpdatedAt,
      Value<int?> lastActivityAt,
      Value<int?> lastSeenAt,
      Value<int?> lastUserMessageAt,
      required String pluginId,
      Value<String?> title,
      Value<String?> catalogTitle,
      Value<SessionApprovalMode?> approvalOverride,
      Value<bool> pinned,
      Value<String?> scheduledTaskId,
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
      Value<bool> fastMode,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> projectionUpdatedAt,
      Value<int?> lastActivityAt,
      Value<int?> lastSeenAt,
      Value<int?> lastUserMessageAt,
      Value<String> pluginId,
      Value<String?> title,
      Value<String?> catalogTitle,
      Value<SessionApprovalMode?> approvalOverride,
      Value<bool> pinned,
      Value<String?> scheduledTaskId,
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

  static $ScheduledTasksTableTable _scheduledTaskIdTable(_$AppDatabase db) => db
      .scheduledTasksTable
      .createAlias('sessions_table__scheduled_task_id__scheduled_tasks__id');

  $$ScheduledTasksTableTableProcessedTableManager? get scheduledTaskId {
    final $_column = $_itemColumn<String>('scheduled_task_id');
    if ($_column == null) return null;
    final manager = $$ScheduledTasksTableTableTableManager(
      $_db,
      $_db.scheduledTasksTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scheduledTaskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ScheduledTasksTableTable, List<ScheduledTaskDto>>
  _scheduledTasksTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.scheduledTasksTable,
        aliasName:
            'sessions_table__session_id__scheduled_tasks__target_session_id',
      );

  $$ScheduledTasksTableTableProcessedTableManager get scheduledTasksTableRefs {
    final manager =
        $$ScheduledTasksTableTableTableManager(
          $_db,
          $_db.scheduledTasksTable,
        ).filter(
          (f) => f.targetSessionId.sessionId.sqlEquals(
            $_itemColumn<String>('session_id')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _scheduledTasksTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $SessionContinuationTableTable,
    List<SessionContinuationDto>
  >
  _sessionContinuationTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.sessionContinuationTable,
        aliasName:
            'sessions_table__session_id__session_continuations__session_id',
      );

  $$SessionContinuationTableTableProcessedTableManager
  get sessionContinuationTableRefs {
    final manager =
        $$SessionContinuationTableTableTableManager(
          $_db,
          $_db.sessionContinuationTable,
        ).filter(
          (f) => f.sessionId.sessionId.sqlEquals(
            $_itemColumn<String>('session_id')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _sessionContinuationTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $SideChatExchangesTableTable,
    List<SideChatExchangeDto>
  >
  _sideChatExchangesTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.sideChatExchangesTable,
        aliasName:
            'sessions_table__session_id__side_chat_exchanges__session_id',
      );

  $$SideChatExchangesTableTableProcessedTableManager
  get sideChatExchangesTableRefs {
    final manager =
        $$SideChatExchangesTableTableTableManager(
          $_db,
          $_db.sideChatExchangesTable,
        ).filter(
          (f) => f.sessionId.sessionId.sqlEquals(
            $_itemColumn<String>('session_id')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _sideChatExchangesTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ScheduledTaskRunsTableTable,
    List<ScheduledTaskRunDto>
  >
  _scheduledTaskRunsTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.scheduledTaskRunsTable,
        aliasName:
            'sessions_table__session_id__scheduled_task_runs__session_id',
      );

  $$ScheduledTaskRunsTableTableProcessedTableManager
  get scheduledTaskRunsTableRefs {
    final manager =
        $$ScheduledTaskRunsTableTableTableManager(
          $_db,
          $_db.scheduledTaskRunsTable,
        ).filter(
          (f) => f.sessionId.sessionId.sqlEquals(
            $_itemColumn<String>('session_id')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _scheduledTaskRunsTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $SessionRunningTurnsTableTable,
    List<SessionRunningTurnDto>
  >
  _sessionRunningTurnsTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.sessionRunningTurnsTable,
        aliasName:
            'sessions_table__session_id__session_running_turns__session_id',
      );

  $$SessionRunningTurnsTableTableProcessedTableManager
  get sessionRunningTurnsTableRefs {
    final manager =
        $$SessionRunningTurnsTableTableTableManager(
          $_db,
          $_db.sessionRunningTurnsTable,
        ).filter(
          (f) => f.sessionId.sessionId.sqlEquals(
            $_itemColumn<String>('session_id')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _sessionRunningTurnsTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $SessionInterruptionsTableTable,
    List<SessionInterruptionDto>
  >
  _sessionInterruptionsTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.sessionInterruptionsTable,
        aliasName:
            'sessions_table__session_id__session_interruptions__session_id',
      );

  $$SessionInterruptionsTableTableProcessedTableManager
  get sessionInterruptionsTableRefs {
    final manager =
        $$SessionInterruptionsTableTableTableManager(
          $_db,
          $_db.sessionInterruptionsTable,
        ).filter(
          (f) => f.sessionId.sessionId.sqlEquals(
            $_itemColumn<String>('session_id')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _sessionInterruptionsTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
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

  ColumnFilters<bool> get fastMode => $composableBuilder(
    column: $table.fastMode,
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

  ColumnWithTypeConverterFilters<
    SessionApprovalMode?,
    SessionApprovalMode,
    String
  >
  get approvalOverride => $composableBuilder(
    column: $table.approvalOverride,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
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

  $$ScheduledTasksTableTableFilterComposer get scheduledTaskId {
    final $$ScheduledTasksTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.scheduledTaskId,
      referencedTable: $db.scheduledTasksTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScheduledTasksTableTableFilterComposer(
            $db: $db,
            $table: $db.scheduledTasksTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> scheduledTasksTableRefs(
    Expression<bool> Function($$ScheduledTasksTableTableFilterComposer f) f,
  ) {
    final $$ScheduledTasksTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.scheduledTasksTable,
      getReferencedColumn: (t) => t.targetSessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScheduledTasksTableTableFilterComposer(
            $db: $db,
            $table: $db.scheduledTasksTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> sessionContinuationTableRefs(
    Expression<bool> Function($$SessionContinuationTableTableFilterComposer f)
    f,
  ) {
    final $$SessionContinuationTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.sessionContinuationTable,
          getReferencedColumn: (t) => t.sessionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SessionContinuationTableTableFilterComposer(
                $db: $db,
                $table: $db.sessionContinuationTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> sideChatExchangesTableRefs(
    Expression<bool> Function($$SideChatExchangesTableTableFilterComposer f) f,
  ) {
    final $$SideChatExchangesTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.sideChatExchangesTable,
          getReferencedColumn: (t) => t.sessionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SideChatExchangesTableTableFilterComposer(
                $db: $db,
                $table: $db.sideChatExchangesTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> scheduledTaskRunsTableRefs(
    Expression<bool> Function($$ScheduledTaskRunsTableTableFilterComposer f) f,
  ) {
    final $$ScheduledTaskRunsTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.scheduledTaskRunsTable,
          getReferencedColumn: (t) => t.sessionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledTaskRunsTableTableFilterComposer(
                $db: $db,
                $table: $db.scheduledTaskRunsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> sessionRunningTurnsTableRefs(
    Expression<bool> Function($$SessionRunningTurnsTableTableFilterComposer f)
    f,
  ) {
    final $$SessionRunningTurnsTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.sessionRunningTurnsTable,
          getReferencedColumn: (t) => t.sessionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SessionRunningTurnsTableTableFilterComposer(
                $db: $db,
                $table: $db.sessionRunningTurnsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> sessionInterruptionsTableRefs(
    Expression<bool> Function($$SessionInterruptionsTableTableFilterComposer f)
    f,
  ) {
    final $$SessionInterruptionsTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.sessionInterruptionsTable,
          getReferencedColumn: (t) => t.sessionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SessionInterruptionsTableTableFilterComposer(
                $db: $db,
                $table: $db.sessionInterruptionsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
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

  ColumnOrderings<bool> get fastMode => $composableBuilder(
    column: $table.fastMode,
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

  ColumnOrderings<String> get approvalOverride => $composableBuilder(
    column: $table.approvalOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
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

  $$ScheduledTasksTableTableOrderingComposer get scheduledTaskId {
    final $$ScheduledTasksTableTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.scheduledTaskId,
          referencedTable: $db.scheduledTasksTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledTasksTableTableOrderingComposer(
                $db: $db,
                $table: $db.scheduledTasksTable,
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

  GeneratedColumn<bool> get fastMode =>
      $composableBuilder(column: $table.fastMode, builder: (column) => column);

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

  GeneratedColumnWithTypeConverter<SessionApprovalMode?, String>
  get approvalOverride => $composableBuilder(
    column: $table.approvalOverride,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

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

  $$ScheduledTasksTableTableAnnotationComposer get scheduledTaskId {
    final $$ScheduledTasksTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.scheduledTaskId,
          referencedTable: $db.scheduledTasksTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledTasksTableTableAnnotationComposer(
                $db: $db,
                $table: $db.scheduledTasksTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  Expression<T> scheduledTasksTableRefs<T extends Object>(
    Expression<T> Function($$ScheduledTasksTableTableAnnotationComposer a) f,
  ) {
    final $$ScheduledTasksTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.scheduledTasksTable,
          getReferencedColumn: (t) => t.targetSessionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledTasksTableTableAnnotationComposer(
                $db: $db,
                $table: $db.scheduledTasksTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> sessionContinuationTableRefs<T extends Object>(
    Expression<T> Function($$SessionContinuationTableTableAnnotationComposer a)
    f,
  ) {
    final $$SessionContinuationTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.sessionContinuationTable,
          getReferencedColumn: (t) => t.sessionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SessionContinuationTableTableAnnotationComposer(
                $db: $db,
                $table: $db.sessionContinuationTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> sideChatExchangesTableRefs<T extends Object>(
    Expression<T> Function($$SideChatExchangesTableTableAnnotationComposer a) f,
  ) {
    final $$SideChatExchangesTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.sideChatExchangesTable,
          getReferencedColumn: (t) => t.sessionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SideChatExchangesTableTableAnnotationComposer(
                $db: $db,
                $table: $db.sideChatExchangesTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> scheduledTaskRunsTableRefs<T extends Object>(
    Expression<T> Function($$ScheduledTaskRunsTableTableAnnotationComposer a) f,
  ) {
    final $$ScheduledTaskRunsTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.scheduledTaskRunsTable,
          getReferencedColumn: (t) => t.sessionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledTaskRunsTableTableAnnotationComposer(
                $db: $db,
                $table: $db.scheduledTaskRunsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> sessionRunningTurnsTableRefs<T extends Object>(
    Expression<T> Function($$SessionRunningTurnsTableTableAnnotationComposer a)
    f,
  ) {
    final $$SessionRunningTurnsTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.sessionRunningTurnsTable,
          getReferencedColumn: (t) => t.sessionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SessionRunningTurnsTableTableAnnotationComposer(
                $db: $db,
                $table: $db.sessionRunningTurnsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> sessionInterruptionsTableRefs<T extends Object>(
    Expression<T> Function($$SessionInterruptionsTableTableAnnotationComposer a)
    f,
  ) {
    final $$SessionInterruptionsTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sessionId,
          referencedTable: $db.sessionInterruptionsTable,
          getReferencedColumn: (t) => t.sessionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SessionInterruptionsTableTableAnnotationComposer(
                $db: $db,
                $table: $db.sessionInterruptionsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
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
          PrefetchHooks Function({
            bool projectId,
            bool parentSessionId,
            bool scheduledTaskId,
            bool scheduledTasksTableRefs,
            bool sessionContinuationTableRefs,
            bool sideChatExchangesTableRefs,
            bool scheduledTaskRunsTableRefs,
            bool sessionRunningTurnsTableRefs,
            bool sessionInterruptionsTableRefs,
          })
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
                Value<bool> fastMode = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> projectionUpdatedAt = const Value.absent(),
                Value<int?> lastActivityAt = const Value.absent(),
                Value<int?> lastSeenAt = const Value.absent(),
                Value<int?> lastUserMessageAt = const Value.absent(),
                Value<String> pluginId = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> catalogTitle = const Value.absent(),
                Value<SessionApprovalMode?> approvalOverride =
                    const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<String?> scheduledTaskId = const Value.absent(),
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
                fastMode: fastMode,
                createdAt: createdAt,
                updatedAt: updatedAt,
                projectionUpdatedAt: projectionUpdatedAt,
                lastActivityAt: lastActivityAt,
                lastSeenAt: lastSeenAt,
                lastUserMessageAt: lastUserMessageAt,
                pluginId: pluginId,
                title: title,
                catalogTitle: catalogTitle,
                approvalOverride: approvalOverride,
                pinned: pinned,
                scheduledTaskId: scheduledTaskId,
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
                Value<bool> fastMode = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                required int projectionUpdatedAt,
                Value<int?> lastActivityAt = const Value.absent(),
                Value<int?> lastSeenAt = const Value.absent(),
                Value<int?> lastUserMessageAt = const Value.absent(),
                required String pluginId,
                Value<String?> title = const Value.absent(),
                Value<String?> catalogTitle = const Value.absent(),
                Value<SessionApprovalMode?> approvalOverride =
                    const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<String?> scheduledTaskId = const Value.absent(),
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
                fastMode: fastMode,
                createdAt: createdAt,
                updatedAt: updatedAt,
                projectionUpdatedAt: projectionUpdatedAt,
                lastActivityAt: lastActivityAt,
                lastSeenAt: lastSeenAt,
                lastUserMessageAt: lastUserMessageAt,
                pluginId: pluginId,
                title: title,
                catalogTitle: catalogTitle,
                approvalOverride: approvalOverride,
                pinned: pinned,
                scheduledTaskId: scheduledTaskId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionTableTable, SessionDto>(table),
                  $$SessionTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                projectId = false,
                parentSessionId = false,
                scheduledTaskId = false,
                scheduledTasksTableRefs = false,
                sessionContinuationTableRefs = false,
                sideChatExchangesTableRefs = false,
                scheduledTaskRunsTableRefs = false,
                sessionRunningTurnsTableRefs = false,
                sessionInterruptionsTableRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (scheduledTasksTableRefs) db.scheduledTasksTable,
                    if (sessionContinuationTableRefs)
                      db.sessionContinuationTable,
                    if (sideChatExchangesTableRefs) db.sideChatExchangesTable,
                    if (scheduledTaskRunsTableRefs) db.scheduledTaskRunsTable,
                    if (sessionRunningTurnsTableRefs)
                      db.sessionRunningTurnsTable,
                    if (sessionInterruptionsTableRefs)
                      db.sessionInterruptionsTable,
                  ],
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
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.projectId,
                            referencedTable: $$SessionTableTableReferences
                                ._projectIdTable(db),
                            referencedColumn: $$SessionTableTableReferences
                                ._projectIdTable(db)
                                .projectId,
                          ) as T;
                        }
                        if (parentSessionId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.parentSessionId,
                            referencedTable: $$SessionTableTableReferences
                                ._parentSessionIdTable(db),
                            referencedColumn: $$SessionTableTableReferences
                                ._parentSessionIdTable(db)
                                .sessionId,
                          ) as T;
                        }
                        if (scheduledTaskId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.scheduledTaskId,
                            referencedTable: $$SessionTableTableReferences
                                ._scheduledTaskIdTable(db),
                            referencedColumn: $$SessionTableTableReferences
                                ._scheduledTaskIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (scheduledTasksTableRefs)
                        await $_getPrefetchedDataByColumns<
                          SessionDto,
                          $SessionTableTable,
                          ScheduledTaskDto,
                          $ScheduledTasksTableTable
                        >(
                          currentTable: table,
                          referencedTable: $$SessionTableTableReferences
                              ._scheduledTasksTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionTableTableReferences(
                                db,
                                table,
                                p0,
                              ).scheduledTasksTableRefs,
                          currentColumn: 'session_id',
                          referencedColumn: 'target_session_id',
                          typedResults: items,
                        ),
                      if (sessionContinuationTableRefs)
                        await $_getPrefetchedDataByColumns<
                          SessionDto,
                          $SessionTableTable,
                          SessionContinuationDto,
                          $SessionContinuationTableTable
                        >(
                          currentTable: table,
                          referencedTable: $$SessionTableTableReferences
                              ._sessionContinuationTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionTableTableReferences(
                                db,
                                table,
                                p0,
                              ).sessionContinuationTableRefs,
                          currentColumn: 'session_id',
                          referencedColumn: 'session_id',
                          typedResults: items,
                        ),
                      if (sideChatExchangesTableRefs)
                        await $_getPrefetchedDataByColumns<
                          SessionDto,
                          $SessionTableTable,
                          SideChatExchangeDto,
                          $SideChatExchangesTableTable
                        >(
                          currentTable: table,
                          referencedTable: $$SessionTableTableReferences
                              ._sideChatExchangesTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionTableTableReferences(
                                db,
                                table,
                                p0,
                              ).sideChatExchangesTableRefs,
                          currentColumn: 'session_id',
                          referencedColumn: 'session_id',
                          typedResults: items,
                        ),
                      if (scheduledTaskRunsTableRefs)
                        await $_getPrefetchedDataByColumns<
                          SessionDto,
                          $SessionTableTable,
                          ScheduledTaskRunDto,
                          $ScheduledTaskRunsTableTable
                        >(
                          currentTable: table,
                          referencedTable: $$SessionTableTableReferences
                              ._scheduledTaskRunsTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionTableTableReferences(
                                db,
                                table,
                                p0,
                              ).scheduledTaskRunsTableRefs,
                          currentColumn: 'session_id',
                          referencedColumn: 'session_id',
                          typedResults: items,
                        ),
                      if (sessionRunningTurnsTableRefs)
                        await $_getPrefetchedDataByColumns<
                          SessionDto,
                          $SessionTableTable,
                          SessionRunningTurnDto,
                          $SessionRunningTurnsTableTable
                        >(
                          currentTable: table,
                          referencedTable: $$SessionTableTableReferences
                              ._sessionRunningTurnsTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionTableTableReferences(
                                db,
                                table,
                                p0,
                              ).sessionRunningTurnsTableRefs,
                          currentColumn: 'session_id',
                          referencedColumn: 'session_id',
                          typedResults: items,
                        ),
                      if (sessionInterruptionsTableRefs)
                        await $_getPrefetchedDataByColumns<
                          SessionDto,
                          $SessionTableTable,
                          SessionInterruptionDto,
                          $SessionInterruptionsTableTable
                        >(
                          currentTable: table,
                          referencedTable: $$SessionTableTableReferences
                              ._sessionInterruptionsTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SessionTableTableReferences(
                                db,
                                table,
                                p0,
                              ).sessionInterruptionsTableRefs,
                          currentColumn: 'session_id',
                          referencedColumn: 'session_id',
                          typedResults: items,
                        ),
                    ];
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
      PrefetchHooks Function({
        bool projectId,
        bool parentSessionId,
        bool scheduledTaskId,
        bool scheduledTasksTableRefs,
        bool sessionContinuationTableRefs,
        bool sideChatExchangesTableRefs,
        bool scheduledTaskRunsTableRefs,
        bool sessionRunningTurnsTableRefs,
        bool sessionInterruptionsTableRefs,
      })
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
              .map(
                (e) => (
                  e.readTable<$DeletedSessionsTableTable, DeletedSessionDto>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $DeletedSessionsTableTable,
                    DeletedSessionDto
                  >(db, table, e),
                ),
              )
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
              .map(
                (e) => (
                  e.readTable<
                    $CatalogHydrationsTableTable,
                    CatalogHydrationDto
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CatalogHydrationsTableTable,
                    CatalogHydrationDto
                  >(db, table, e),
                ),
              )
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
typedef $$SessionOptionsCacheTableTableCreateCompanionBuilder =
    SessionOptionsCacheTableCompanion Function({
      required String pluginId,
      required PluginSessionOptionsScope scope,
      required String ownerId,
      Value<String?> projectId,
      Value<String?> capturedProjectPath,
      required int revision,
      required int capturedAt,
      required String agentsJson,
      required String providersJson,
      required String commandsJson,
    });
typedef $$SessionOptionsCacheTableTableUpdateCompanionBuilder =
    SessionOptionsCacheTableCompanion Function({
      Value<String> pluginId,
      Value<PluginSessionOptionsScope> scope,
      Value<String> ownerId,
      Value<String?> projectId,
      Value<String?> capturedProjectPath,
      Value<int> revision,
      Value<int> capturedAt,
      Value<String> agentsJson,
      Value<String> providersJson,
      Value<String> commandsJson,
    });

class $$SessionOptionsCacheTableTableFilterComposer
    extends Composer<_$AppDatabase, $SessionOptionsCacheTableTable> {
  $$SessionOptionsCacheTableTableFilterComposer({
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

  ColumnWithTypeConverterFilters<
    PluginSessionOptionsScope,
    PluginSessionOptionsScope,
    String
  >
  get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capturedProjectPath => $composableBuilder(
    column: $table.capturedProjectPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get agentsJson => $composableBuilder(
    column: $table.agentsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providersJson => $composableBuilder(
    column: $table.providersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commandsJson => $composableBuilder(
    column: $table.commandsJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionOptionsCacheTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionOptionsCacheTableTable> {
  $$SessionOptionsCacheTableTableOrderingComposer({
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

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capturedProjectPath => $composableBuilder(
    column: $table.capturedProjectPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get agentsJson => $composableBuilder(
    column: $table.agentsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providersJson => $composableBuilder(
    column: $table.providersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commandsJson => $composableBuilder(
    column: $table.commandsJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionOptionsCacheTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionOptionsCacheTableTable> {
  $$SessionOptionsCacheTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get pluginId =>
      $composableBuilder(column: $table.pluginId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PluginSessionOptionsScope, String>
  get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get capturedProjectPath => $composableBuilder(
    column: $table.capturedProjectPath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get agentsJson => $composableBuilder(
    column: $table.agentsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providersJson => $composableBuilder(
    column: $table.providersJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get commandsJson => $composableBuilder(
    column: $table.commandsJson,
    builder: (column) => column,
  );
}

class $$SessionOptionsCacheTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionOptionsCacheTableTable,
          SessionOptionsCacheTableData,
          $$SessionOptionsCacheTableTableFilterComposer,
          $$SessionOptionsCacheTableTableOrderingComposer,
          $$SessionOptionsCacheTableTableAnnotationComposer,
          $$SessionOptionsCacheTableTableCreateCompanionBuilder,
          $$SessionOptionsCacheTableTableUpdateCompanionBuilder,
          (
            SessionOptionsCacheTableData,
            BaseReferences<
              _$AppDatabase,
              $SessionOptionsCacheTableTable,
              SessionOptionsCacheTableData
            >,
          ),
          SessionOptionsCacheTableData,
          PrefetchHooks Function()
        > {
  $$SessionOptionsCacheTableTableTableManager(
    _$AppDatabase db,
    $SessionOptionsCacheTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionOptionsCacheTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SessionOptionsCacheTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SessionOptionsCacheTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> pluginId = const Value.absent(),
                Value<PluginSessionOptionsScope> scope = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String?> projectId = const Value.absent(),
                Value<String?> capturedProjectPath = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<int> capturedAt = const Value.absent(),
                Value<String> agentsJson = const Value.absent(),
                Value<String> providersJson = const Value.absent(),
                Value<String> commandsJson = const Value.absent(),
              }) => SessionOptionsCacheTableCompanion(
                pluginId: pluginId,
                scope: scope,
                ownerId: ownerId,
                projectId: projectId,
                capturedProjectPath: capturedProjectPath,
                revision: revision,
                capturedAt: capturedAt,
                agentsJson: agentsJson,
                providersJson: providersJson,
                commandsJson: commandsJson,
              ),
          createCompanionCallback:
              ({
                required String pluginId,
                required PluginSessionOptionsScope scope,
                required String ownerId,
                Value<String?> projectId = const Value.absent(),
                Value<String?> capturedProjectPath = const Value.absent(),
                required int revision,
                required int capturedAt,
                required String agentsJson,
                required String providersJson,
                required String commandsJson,
              }) => SessionOptionsCacheTableCompanion.insert(
                pluginId: pluginId,
                scope: scope,
                ownerId: ownerId,
                projectId: projectId,
                capturedProjectPath: capturedProjectPath,
                revision: revision,
                capturedAt: capturedAt,
                agentsJson: agentsJson,
                providersJson: providersJson,
                commandsJson: commandsJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $SessionOptionsCacheTableTable,
                    SessionOptionsCacheTableData
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SessionOptionsCacheTableTable,
                    SessionOptionsCacheTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionOptionsCacheTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionOptionsCacheTableTable,
      SessionOptionsCacheTableData,
      $$SessionOptionsCacheTableTableFilterComposer,
      $$SessionOptionsCacheTableTableOrderingComposer,
      $$SessionOptionsCacheTableTableAnnotationComposer,
      $$SessionOptionsCacheTableTableCreateCompanionBuilder,
      $$SessionOptionsCacheTableTableUpdateCompanionBuilder,
      (
        SessionOptionsCacheTableData,
        BaseReferences<
          _$AppDatabase,
          $SessionOptionsCacheTableTable,
          SessionOptionsCacheTableData
        >,
      ),
      SessionOptionsCacheTableData,
      PrefetchHooks Function()
    >;
typedef $$NewSessionDefaultsTableTableCreateCompanionBuilder =
    NewSessionDefaultsTableCompanion Function({
      required String pluginId,
      Value<String?> agent,
      Value<AgentModel?> agentModel,
      Value<bool> fastMode,
    });
typedef $$NewSessionDefaultsTableTableUpdateCompanionBuilder =
    NewSessionDefaultsTableCompanion Function({
      Value<String> pluginId,
      Value<String?> agent,
      Value<AgentModel?> agentModel,
      Value<bool> fastMode,
    });

class $$NewSessionDefaultsTableTableFilterComposer
    extends Composer<_$AppDatabase, $NewSessionDefaultsTableTable> {
  $$NewSessionDefaultsTableTableFilterComposer({
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

  ColumnFilters<String> get agent => $composableBuilder(
    column: $table.agent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AgentModel?, AgentModel, String>
  get agentModel => $composableBuilder(
    column: $table.agentModel,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get fastMode => $composableBuilder(
    column: $table.fastMode,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NewSessionDefaultsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $NewSessionDefaultsTableTable> {
  $$NewSessionDefaultsTableTableOrderingComposer({
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

  ColumnOrderings<String> get agent => $composableBuilder(
    column: $table.agent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get agentModel => $composableBuilder(
    column: $table.agentModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get fastMode => $composableBuilder(
    column: $table.fastMode,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NewSessionDefaultsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $NewSessionDefaultsTableTable> {
  $$NewSessionDefaultsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get pluginId =>
      $composableBuilder(column: $table.pluginId, builder: (column) => column);

  GeneratedColumn<String> get agent =>
      $composableBuilder(column: $table.agent, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AgentModel?, String> get agentModel =>
      $composableBuilder(
        column: $table.agentModel,
        builder: (column) => column,
      );

  GeneratedColumn<bool> get fastMode =>
      $composableBuilder(column: $table.fastMode, builder: (column) => column);
}

class $$NewSessionDefaultsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NewSessionDefaultsTableTable,
          NewSessionDefaultsTableData,
          $$NewSessionDefaultsTableTableFilterComposer,
          $$NewSessionDefaultsTableTableOrderingComposer,
          $$NewSessionDefaultsTableTableAnnotationComposer,
          $$NewSessionDefaultsTableTableCreateCompanionBuilder,
          $$NewSessionDefaultsTableTableUpdateCompanionBuilder,
          (
            NewSessionDefaultsTableData,
            BaseReferences<
              _$AppDatabase,
              $NewSessionDefaultsTableTable,
              NewSessionDefaultsTableData
            >,
          ),
          NewSessionDefaultsTableData,
          PrefetchHooks Function()
        > {
  $$NewSessionDefaultsTableTableTableManager(
    _$AppDatabase db,
    $NewSessionDefaultsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NewSessionDefaultsTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$NewSessionDefaultsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$NewSessionDefaultsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> pluginId = const Value.absent(),
                Value<String?> agent = const Value.absent(),
                Value<AgentModel?> agentModel = const Value.absent(),
                Value<bool> fastMode = const Value.absent(),
              }) => NewSessionDefaultsTableCompanion(
                pluginId: pluginId,
                agent: agent,
                agentModel: agentModel,
                fastMode: fastMode,
              ),
          createCompanionCallback:
              ({
                required String pluginId,
                Value<String?> agent = const Value.absent(),
                Value<AgentModel?> agentModel = const Value.absent(),
                Value<bool> fastMode = const Value.absent(),
              }) => NewSessionDefaultsTableCompanion.insert(
                pluginId: pluginId,
                agent: agent,
                agentModel: agentModel,
                fastMode: fastMode,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $NewSessionDefaultsTableTable,
                    NewSessionDefaultsTableData
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $NewSessionDefaultsTableTable,
                    NewSessionDefaultsTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NewSessionDefaultsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NewSessionDefaultsTableTable,
      NewSessionDefaultsTableData,
      $$NewSessionDefaultsTableTableFilterComposer,
      $$NewSessionDefaultsTableTableOrderingComposer,
      $$NewSessionDefaultsTableTableAnnotationComposer,
      $$NewSessionDefaultsTableTableCreateCompanionBuilder,
      $$NewSessionDefaultsTableTableUpdateCompanionBuilder,
      (
        NewSessionDefaultsTableData,
        BaseReferences<
          _$AppDatabase,
          $NewSessionDefaultsTableTable,
          NewSessionDefaultsTableData
        >,
      ),
      NewSessionDefaultsTableData,
      PrefetchHooks Function()
    >;
typedef $$AcceptedPromptsTableTableCreateCompanionBuilder =
    AcceptedPromptsTableCompanion Function({
      required String sessionId,
      required String promptId,
      required int acceptedAt,
    });
typedef $$AcceptedPromptsTableTableUpdateCompanionBuilder =
    AcceptedPromptsTableCompanion Function({
      Value<String> sessionId,
      Value<String> promptId,
      Value<int> acceptedAt,
    });

class $$AcceptedPromptsTableTableFilterComposer
    extends Composer<_$AppDatabase, $AcceptedPromptsTableTable> {
  $$AcceptedPromptsTableTableFilterComposer({
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

  ColumnFilters<String> get promptId => $composableBuilder(
    column: $table.promptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get acceptedAt => $composableBuilder(
    column: $table.acceptedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AcceptedPromptsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AcceptedPromptsTableTable> {
  $$AcceptedPromptsTableTableOrderingComposer({
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

  ColumnOrderings<String> get promptId => $composableBuilder(
    column: $table.promptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get acceptedAt => $composableBuilder(
    column: $table.acceptedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AcceptedPromptsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AcceptedPromptsTableTable> {
  $$AcceptedPromptsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get promptId =>
      $composableBuilder(column: $table.promptId, builder: (column) => column);

  GeneratedColumn<int> get acceptedAt => $composableBuilder(
    column: $table.acceptedAt,
    builder: (column) => column,
  );
}

class $$AcceptedPromptsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AcceptedPromptsTableTable,
          AcceptedPromptsTableData,
          $$AcceptedPromptsTableTableFilterComposer,
          $$AcceptedPromptsTableTableOrderingComposer,
          $$AcceptedPromptsTableTableAnnotationComposer,
          $$AcceptedPromptsTableTableCreateCompanionBuilder,
          $$AcceptedPromptsTableTableUpdateCompanionBuilder,
          (
            AcceptedPromptsTableData,
            BaseReferences<
              _$AppDatabase,
              $AcceptedPromptsTableTable,
              AcceptedPromptsTableData
            >,
          ),
          AcceptedPromptsTableData,
          PrefetchHooks Function()
        > {
  $$AcceptedPromptsTableTableTableManager(
    _$AppDatabase db,
    $AcceptedPromptsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AcceptedPromptsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AcceptedPromptsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AcceptedPromptsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<String> promptId = const Value.absent(),
                Value<int> acceptedAt = const Value.absent(),
              }) => AcceptedPromptsTableCompanion(
                sessionId: sessionId,
                promptId: promptId,
                acceptedAt: acceptedAt,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required String promptId,
                required int acceptedAt,
              }) => AcceptedPromptsTableCompanion.insert(
                sessionId: sessionId,
                promptId: promptId,
                acceptedAt: acceptedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $AcceptedPromptsTableTable,
                    AcceptedPromptsTableData
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AcceptedPromptsTableTable,
                    AcceptedPromptsTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AcceptedPromptsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AcceptedPromptsTableTable,
      AcceptedPromptsTableData,
      $$AcceptedPromptsTableTableFilterComposer,
      $$AcceptedPromptsTableTableOrderingComposer,
      $$AcceptedPromptsTableTableAnnotationComposer,
      $$AcceptedPromptsTableTableCreateCompanionBuilder,
      $$AcceptedPromptsTableTableUpdateCompanionBuilder,
      (
        AcceptedPromptsTableData,
        BaseReferences<
          _$AppDatabase,
          $AcceptedPromptsTableTable,
          AcceptedPromptsTableData
        >,
      ),
      AcceptedPromptsTableData,
      PrefetchHooks Function()
    >;
typedef $$SessionContinuationTableTableCreateCompanionBuilder =
    SessionContinuationTableCompanion Function({
      required String sessionId,
      required bool enabled,
      required String outcomeJson,
    });
typedef $$SessionContinuationTableTableUpdateCompanionBuilder =
    SessionContinuationTableCompanion Function({
      Value<String> sessionId,
      Value<bool> enabled,
      Value<String> outcomeJson,
    });

final class $$SessionContinuationTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $SessionContinuationTableTable,
          SessionContinuationDto
        > {
  $$SessionContinuationTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SessionTableTable _sessionIdTable(_$AppDatabase db) =>
      db.sessionTable.createAlias(
        'session_continuations__session_id__sessions_table__session_id',
      );

  $$SessionTableTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionTableTableTableManager(
      $_db,
      $_db.sessionTable,
    ).filter((f) => f.sessionId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SessionContinuationTableTableFilterComposer
    extends Composer<_$AppDatabase, $SessionContinuationTableTable> {
  $$SessionContinuationTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outcomeJson => $composableBuilder(
    column: $table.outcomeJson,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionTableTableFilterComposer get sessionId {
    final $$SessionTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
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

class $$SessionContinuationTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionContinuationTableTable> {
  $$SessionContinuationTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcomeJson => $composableBuilder(
    column: $table.outcomeJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionTableTableOrderingComposer get sessionId {
    final $$SessionTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
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

class $$SessionContinuationTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionContinuationTableTable> {
  $$SessionContinuationTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get outcomeJson => $composableBuilder(
    column: $table.outcomeJson,
    builder: (column) => column,
  );

  $$SessionTableTableAnnotationComposer get sessionId {
    final $$SessionTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
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

class $$SessionContinuationTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionContinuationTableTable,
          SessionContinuationDto,
          $$SessionContinuationTableTableFilterComposer,
          $$SessionContinuationTableTableOrderingComposer,
          $$SessionContinuationTableTableAnnotationComposer,
          $$SessionContinuationTableTableCreateCompanionBuilder,
          $$SessionContinuationTableTableUpdateCompanionBuilder,
          (SessionContinuationDto, $$SessionContinuationTableTableReferences),
          SessionContinuationDto,
          PrefetchHooks Function({bool sessionId})
        > {
  $$SessionContinuationTableTableTableManager(
    _$AppDatabase db,
    $SessionContinuationTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionContinuationTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SessionContinuationTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SessionContinuationTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String> outcomeJson = const Value.absent(),
              }) => SessionContinuationTableCompanion(
                sessionId: sessionId,
                enabled: enabled,
                outcomeJson: outcomeJson,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required bool enabled,
                required String outcomeJson,
              }) => SessionContinuationTableCompanion.insert(
                sessionId: sessionId,
                enabled: enabled,
                outcomeJson: outcomeJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $SessionContinuationTableTable,
                    SessionContinuationDto
                  >(table),
                  $$SessionContinuationTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
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
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable:
                            $$SessionContinuationTableTableReferences
                                ._sessionIdTable(db),
                        referencedColumn:
                            $$SessionContinuationTableTableReferences
                                ._sessionIdTable(db)
                                .sessionId,
                      ) as T;
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

typedef $$SessionContinuationTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionContinuationTableTable,
      SessionContinuationDto,
      $$SessionContinuationTableTableFilterComposer,
      $$SessionContinuationTableTableOrderingComposer,
      $$SessionContinuationTableTableAnnotationComposer,
      $$SessionContinuationTableTableCreateCompanionBuilder,
      $$SessionContinuationTableTableUpdateCompanionBuilder,
      (SessionContinuationDto, $$SessionContinuationTableTableReferences),
      SessionContinuationDto,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$SideChatExchangesTableTableCreateCompanionBuilder =
    SideChatExchangesTableCompanion Function({
      required String id,
      required String sessionId,
      required String sideChatId,
      required String question,
      required String answer,
      Value<String?> answerNotice,
      required int askedAt,
      required int answeredAt,
    });
typedef $$SideChatExchangesTableTableUpdateCompanionBuilder =
    SideChatExchangesTableCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String> sideChatId,
      Value<String> question,
      Value<String> answer,
      Value<String?> answerNotice,
      Value<int> askedAt,
      Value<int> answeredAt,
    });

final class $$SideChatExchangesTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $SideChatExchangesTableTable,
          SideChatExchangeDto
        > {
  $$SideChatExchangesTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SessionTableTable _sessionIdTable(_$AppDatabase db) =>
      db.sessionTable.createAlias(
        'side_chat_exchanges__session_id__sessions_table__session_id',
      );

  $$SessionTableTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionTableTableTableManager(
      $_db,
      $_db.sessionTable,
    ).filter((f) => f.sessionId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SideChatExchangesTableTableFilterComposer
    extends Composer<_$AppDatabase, $SideChatExchangesTableTable> {
  $$SideChatExchangesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sideChatId => $composableBuilder(
    column: $table.sideChatId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answerNotice => $composableBuilder(
    column: $table.answerNotice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get askedAt => $composableBuilder(
    column: $table.askedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get answeredAt => $composableBuilder(
    column: $table.answeredAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionTableTableFilterComposer get sessionId {
    final $$SessionTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
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

class $$SideChatExchangesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SideChatExchangesTableTable> {
  $$SideChatExchangesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sideChatId => $composableBuilder(
    column: $table.sideChatId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answerNotice => $composableBuilder(
    column: $table.answerNotice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get askedAt => $composableBuilder(
    column: $table.askedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get answeredAt => $composableBuilder(
    column: $table.answeredAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionTableTableOrderingComposer get sessionId {
    final $$SessionTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
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

class $$SideChatExchangesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SideChatExchangesTableTable> {
  $$SideChatExchangesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sideChatId => $composableBuilder(
    column: $table.sideChatId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get question =>
      $composableBuilder(column: $table.question, builder: (column) => column);

  GeneratedColumn<String> get answer =>
      $composableBuilder(column: $table.answer, builder: (column) => column);

  GeneratedColumn<String> get answerNotice => $composableBuilder(
    column: $table.answerNotice,
    builder: (column) => column,
  );

  GeneratedColumn<int> get askedAt =>
      $composableBuilder(column: $table.askedAt, builder: (column) => column);

  GeneratedColumn<int> get answeredAt => $composableBuilder(
    column: $table.answeredAt,
    builder: (column) => column,
  );

  $$SessionTableTableAnnotationComposer get sessionId {
    final $$SessionTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
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

class $$SideChatExchangesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SideChatExchangesTableTable,
          SideChatExchangeDto,
          $$SideChatExchangesTableTableFilterComposer,
          $$SideChatExchangesTableTableOrderingComposer,
          $$SideChatExchangesTableTableAnnotationComposer,
          $$SideChatExchangesTableTableCreateCompanionBuilder,
          $$SideChatExchangesTableTableUpdateCompanionBuilder,
          (SideChatExchangeDto, $$SideChatExchangesTableTableReferences),
          SideChatExchangeDto,
          PrefetchHooks Function({bool sessionId})
        > {
  $$SideChatExchangesTableTableTableManager(
    _$AppDatabase db,
    $SideChatExchangesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SideChatExchangesTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SideChatExchangesTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SideChatExchangesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> sideChatId = const Value.absent(),
                Value<String> question = const Value.absent(),
                Value<String> answer = const Value.absent(),
                Value<String?> answerNotice = const Value.absent(),
                Value<int> askedAt = const Value.absent(),
                Value<int> answeredAt = const Value.absent(),
              }) => SideChatExchangesTableCompanion(
                id: id,
                sessionId: sessionId,
                sideChatId: sideChatId,
                question: question,
                answer: answer,
                answerNotice: answerNotice,
                askedAt: askedAt,
                answeredAt: answeredAt,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String sideChatId,
                required String question,
                required String answer,
                Value<String?> answerNotice = const Value.absent(),
                required int askedAt,
                required int answeredAt,
              }) => SideChatExchangesTableCompanion.insert(
                id: id,
                sessionId: sessionId,
                sideChatId: sideChatId,
                question: question,
                answer: answer,
                answerNotice: answerNotice,
                askedAt: askedAt,
                answeredAt: answeredAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $SideChatExchangesTableTable,
                    SideChatExchangeDto
                  >(table),
                  $$SideChatExchangesTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
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
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $$SideChatExchangesTableTableReferences
                            ._sessionIdTable(db),
                        referencedColumn:
                            $$SideChatExchangesTableTableReferences
                                ._sessionIdTable(db)
                                .sessionId,
                      ) as T;
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

typedef $$SideChatExchangesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SideChatExchangesTableTable,
      SideChatExchangeDto,
      $$SideChatExchangesTableTableFilterComposer,
      $$SideChatExchangesTableTableOrderingComposer,
      $$SideChatExchangesTableTableAnnotationComposer,
      $$SideChatExchangesTableTableCreateCompanionBuilder,
      $$SideChatExchangesTableTableUpdateCompanionBuilder,
      (SideChatExchangeDto, $$SideChatExchangesTableTableReferences),
      SideChatExchangeDto,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$ScheduledTaskRunsTableTableCreateCompanionBuilder =
    ScheduledTaskRunsTableCompanion Function({
      required String id,
      required String taskId,
      Value<String?> sessionId,
      required int scheduledFor,
      required int scheduledForOffsetMinutes,
      required int firedAt,
      required ScheduledTaskRunOutcomeKind outcome,
      Value<TaskRunFailureReason?> reason,
      required bool late,
      Value<int?> userPromptedAt,
      Value<int?> compactRequestedAt,
    });
typedef $$ScheduledTaskRunsTableTableUpdateCompanionBuilder =
    ScheduledTaskRunsTableCompanion Function({
      Value<String> id,
      Value<String> taskId,
      Value<String?> sessionId,
      Value<int> scheduledFor,
      Value<int> scheduledForOffsetMinutes,
      Value<int> firedAt,
      Value<ScheduledTaskRunOutcomeKind> outcome,
      Value<TaskRunFailureReason?> reason,
      Value<bool> late,
      Value<int?> userPromptedAt,
      Value<int?> compactRequestedAt,
    });

final class $$ScheduledTaskRunsTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ScheduledTaskRunsTableTable,
          ScheduledTaskRunDto
        > {
  $$ScheduledTaskRunsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ScheduledTasksTableTable _taskIdTable(_$AppDatabase db) => db
      .scheduledTasksTable
      .createAlias('scheduled_task_runs__task_id__scheduled_tasks__id');

  $$ScheduledTasksTableTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<String>('task_id')!;

    final manager = $$ScheduledTasksTableTableTableManager(
      $_db,
      $_db.scheduledTasksTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SessionTableTable _sessionIdTable(_$AppDatabase db) =>
      db.sessionTable.createAlias(
        'scheduled_task_runs__session_id__sessions_table__session_id',
      );

  $$SessionTableTableProcessedTableManager? get sessionId {
    final $_column = $_itemColumn<String>('session_id');
    if ($_column == null) return null;
    final manager = $$SessionTableTableTableManager(
      $_db,
      $_db.sessionTable,
    ).filter((f) => f.sessionId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ScheduledTaskRunsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ScheduledTaskRunsTableTable> {
  $$ScheduledTaskRunsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scheduledFor => $composableBuilder(
    column: $table.scheduledFor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scheduledForOffsetMinutes => $composableBuilder(
    column: $table.scheduledForOffsetMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get firedAt => $composableBuilder(
    column: $table.firedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    ScheduledTaskRunOutcomeKind,
    ScheduledTaskRunOutcomeKind,
    String
  >
  get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<
    TaskRunFailureReason?,
    TaskRunFailureReason,
    String
  >
  get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get late => $composableBuilder(
    column: $table.late,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userPromptedAt => $composableBuilder(
    column: $table.userPromptedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get compactRequestedAt => $composableBuilder(
    column: $table.compactRequestedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ScheduledTasksTableTableFilterComposer get taskId {
    final $$ScheduledTasksTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.scheduledTasksTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ScheduledTasksTableTableFilterComposer(
            $db: $db,
            $table: $db.scheduledTasksTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SessionTableTableFilterComposer get sessionId {
    final $$SessionTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
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

class $$ScheduledTaskRunsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ScheduledTaskRunsTableTable> {
  $$ScheduledTaskRunsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scheduledFor => $composableBuilder(
    column: $table.scheduledFor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scheduledForOffsetMinutes => $composableBuilder(
    column: $table.scheduledForOffsetMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get firedAt => $composableBuilder(
    column: $table.firedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get late => $composableBuilder(
    column: $table.late,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userPromptedAt => $composableBuilder(
    column: $table.userPromptedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get compactRequestedAt => $composableBuilder(
    column: $table.compactRequestedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ScheduledTasksTableTableOrderingComposer get taskId {
    final $$ScheduledTasksTableTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.taskId,
          referencedTable: $db.scheduledTasksTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledTasksTableTableOrderingComposer(
                $db: $db,
                $table: $db.scheduledTasksTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$SessionTableTableOrderingComposer get sessionId {
    final $$SessionTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
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

class $$ScheduledTaskRunsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScheduledTaskRunsTableTable> {
  $$ScheduledTaskRunsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get scheduledFor => $composableBuilder(
    column: $table.scheduledFor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get scheduledForOffsetMinutes => $composableBuilder(
    column: $table.scheduledForOffsetMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get firedAt =>
      $composableBuilder(column: $table.firedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ScheduledTaskRunOutcomeKind, String>
  get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TaskRunFailureReason?, String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<bool> get late =>
      $composableBuilder(column: $table.late, builder: (column) => column);

  GeneratedColumn<int> get userPromptedAt => $composableBuilder(
    column: $table.userPromptedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get compactRequestedAt => $composableBuilder(
    column: $table.compactRequestedAt,
    builder: (column) => column,
  );

  $$ScheduledTasksTableTableAnnotationComposer get taskId {
    final $$ScheduledTasksTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.taskId,
          referencedTable: $db.scheduledTasksTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledTasksTableTableAnnotationComposer(
                $db: $db,
                $table: $db.scheduledTasksTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$SessionTableTableAnnotationComposer get sessionId {
    final $$SessionTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
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

class $$ScheduledTaskRunsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScheduledTaskRunsTableTable,
          ScheduledTaskRunDto,
          $$ScheduledTaskRunsTableTableFilterComposer,
          $$ScheduledTaskRunsTableTableOrderingComposer,
          $$ScheduledTaskRunsTableTableAnnotationComposer,
          $$ScheduledTaskRunsTableTableCreateCompanionBuilder,
          $$ScheduledTaskRunsTableTableUpdateCompanionBuilder,
          (ScheduledTaskRunDto, $$ScheduledTaskRunsTableTableReferences),
          ScheduledTaskRunDto,
          PrefetchHooks Function({bool taskId, bool sessionId})
        > {
  $$ScheduledTaskRunsTableTableTableManager(
    _$AppDatabase db,
    $ScheduledTaskRunsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScheduledTaskRunsTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ScheduledTaskRunsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ScheduledTaskRunsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
                Value<int> scheduledFor = const Value.absent(),
                Value<int> scheduledForOffsetMinutes = const Value.absent(),
                Value<int> firedAt = const Value.absent(),
                Value<ScheduledTaskRunOutcomeKind> outcome =
                    const Value.absent(),
                Value<TaskRunFailureReason?> reason = const Value.absent(),
                Value<bool> late = const Value.absent(),
                Value<int?> userPromptedAt = const Value.absent(),
                Value<int?> compactRequestedAt = const Value.absent(),
              }) => ScheduledTaskRunsTableCompanion(
                id: id,
                taskId: taskId,
                sessionId: sessionId,
                scheduledFor: scheduledFor,
                scheduledForOffsetMinutes: scheduledForOffsetMinutes,
                firedAt: firedAt,
                outcome: outcome,
                reason: reason,
                late: late,
                userPromptedAt: userPromptedAt,
                compactRequestedAt: compactRequestedAt,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String taskId,
                Value<String?> sessionId = const Value.absent(),
                required int scheduledFor,
                required int scheduledForOffsetMinutes,
                required int firedAt,
                required ScheduledTaskRunOutcomeKind outcome,
                Value<TaskRunFailureReason?> reason = const Value.absent(),
                required bool late,
                Value<int?> userPromptedAt = const Value.absent(),
                Value<int?> compactRequestedAt = const Value.absent(),
              }) => ScheduledTaskRunsTableCompanion.insert(
                id: id,
                taskId: taskId,
                sessionId: sessionId,
                scheduledFor: scheduledFor,
                scheduledForOffsetMinutes: scheduledForOffsetMinutes,
                firedAt: firedAt,
                outcome: outcome,
                reason: reason,
                late: late,
                userPromptedAt: userPromptedAt,
                compactRequestedAt: compactRequestedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $ScheduledTaskRunsTableTable,
                    ScheduledTaskRunDto
                  >(table),
                  $$ScheduledTaskRunsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false, sessionId = false}) {
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
                    if (taskId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.taskId,
                        referencedTable: $$ScheduledTaskRunsTableTableReferences
                            ._taskIdTable(db),
                        referencedColumn:
                            $$ScheduledTaskRunsTableTableReferences
                                ._taskIdTable(db)
                                .id,
                      ) as T;
                    }
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $$ScheduledTaskRunsTableTableReferences
                            ._sessionIdTable(db),
                        referencedColumn:
                            $$ScheduledTaskRunsTableTableReferences
                                ._sessionIdTable(db)
                                .sessionId,
                      ) as T;
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

typedef $$ScheduledTaskRunsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScheduledTaskRunsTableTable,
      ScheduledTaskRunDto,
      $$ScheduledTaskRunsTableTableFilterComposer,
      $$ScheduledTaskRunsTableTableOrderingComposer,
      $$ScheduledTaskRunsTableTableAnnotationComposer,
      $$ScheduledTaskRunsTableTableCreateCompanionBuilder,
      $$ScheduledTaskRunsTableTableUpdateCompanionBuilder,
      (ScheduledTaskRunDto, $$ScheduledTaskRunsTableTableReferences),
      ScheduledTaskRunDto,
      PrefetchHooks Function({bool taskId, bool sessionId})
    >;
typedef $$SessionRunningTurnsTableTableCreateCompanionBuilder =
    SessionRunningTurnsTableCompanion Function({
      required String sessionId,
      required int startedAt,
    });
typedef $$SessionRunningTurnsTableTableUpdateCompanionBuilder =
    SessionRunningTurnsTableCompanion Function({
      Value<String> sessionId,
      Value<int> startedAt,
    });

final class $$SessionRunningTurnsTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $SessionRunningTurnsTableTable,
          SessionRunningTurnDto
        > {
  $$SessionRunningTurnsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SessionTableTable _sessionIdTable(_$AppDatabase db) =>
      db.sessionTable.createAlias(
        'session_running_turns__session_id__sessions_table__session_id',
      );

  $$SessionTableTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionTableTableTableManager(
      $_db,
      $_db.sessionTable,
    ).filter((f) => f.sessionId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SessionRunningTurnsTableTableFilterComposer
    extends Composer<_$AppDatabase, $SessionRunningTurnsTableTable> {
  $$SessionRunningTurnsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionTableTableFilterComposer get sessionId {
    final $$SessionTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
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

class $$SessionRunningTurnsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionRunningTurnsTableTable> {
  $$SessionRunningTurnsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionTableTableOrderingComposer get sessionId {
    final $$SessionTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
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

class $$SessionRunningTurnsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionRunningTurnsTableTable> {
  $$SessionRunningTurnsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  $$SessionTableTableAnnotationComposer get sessionId {
    final $$SessionTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
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

class $$SessionRunningTurnsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionRunningTurnsTableTable,
          SessionRunningTurnDto,
          $$SessionRunningTurnsTableTableFilterComposer,
          $$SessionRunningTurnsTableTableOrderingComposer,
          $$SessionRunningTurnsTableTableAnnotationComposer,
          $$SessionRunningTurnsTableTableCreateCompanionBuilder,
          $$SessionRunningTurnsTableTableUpdateCompanionBuilder,
          (SessionRunningTurnDto, $$SessionRunningTurnsTableTableReferences),
          SessionRunningTurnDto,
          PrefetchHooks Function({bool sessionId})
        > {
  $$SessionRunningTurnsTableTableTableManager(
    _$AppDatabase db,
    $SessionRunningTurnsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionRunningTurnsTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SessionRunningTurnsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SessionRunningTurnsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<int> startedAt = const Value.absent(),
              }) => SessionRunningTurnsTableCompanion(
                sessionId: sessionId,
                startedAt: startedAt,
              ),
          createCompanionCallback:
              ({required String sessionId, required int startedAt}) =>
                  SessionRunningTurnsTableCompanion.insert(
                    sessionId: sessionId,
                    startedAt: startedAt,
                  ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $SessionRunningTurnsTableTable,
                    SessionRunningTurnDto
                  >(table),
                  $$SessionRunningTurnsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
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
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable:
                            $$SessionRunningTurnsTableTableReferences
                                ._sessionIdTable(db),
                        referencedColumn:
                            $$SessionRunningTurnsTableTableReferences
                                ._sessionIdTable(db)
                                .sessionId,
                      ) as T;
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

typedef $$SessionRunningTurnsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionRunningTurnsTableTable,
      SessionRunningTurnDto,
      $$SessionRunningTurnsTableTableFilterComposer,
      $$SessionRunningTurnsTableTableOrderingComposer,
      $$SessionRunningTurnsTableTableAnnotationComposer,
      $$SessionRunningTurnsTableTableCreateCompanionBuilder,
      $$SessionRunningTurnsTableTableUpdateCompanionBuilder,
      (SessionRunningTurnDto, $$SessionRunningTurnsTableTableReferences),
      SessionRunningTurnDto,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$SessionInterruptionsTableTableCreateCompanionBuilder =
    SessionInterruptionsTableCompanion Function({
      required String sessionId,
      required String afterMessageId,
      required bool acknowledged,
    });
typedef $$SessionInterruptionsTableTableUpdateCompanionBuilder =
    SessionInterruptionsTableCompanion Function({
      Value<String> sessionId,
      Value<String> afterMessageId,
      Value<bool> acknowledged,
    });

final class $$SessionInterruptionsTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $SessionInterruptionsTableTable,
          SessionInterruptionDto
        > {
  $$SessionInterruptionsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SessionTableTable _sessionIdTable(_$AppDatabase db) =>
      db.sessionTable.createAlias(
        'session_interruptions__session_id__sessions_table__session_id',
      );

  $$SessionTableTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionTableTableTableManager(
      $_db,
      $_db.sessionTable,
    ).filter((f) => f.sessionId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SessionInterruptionsTableTableFilterComposer
    extends Composer<_$AppDatabase, $SessionInterruptionsTableTable> {
  $$SessionInterruptionsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get afterMessageId => $composableBuilder(
    column: $table.afterMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get acknowledged => $composableBuilder(
    column: $table.acknowledged,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionTableTableFilterComposer get sessionId {
    final $$SessionTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
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

class $$SessionInterruptionsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionInterruptionsTableTable> {
  $$SessionInterruptionsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get afterMessageId => $composableBuilder(
    column: $table.afterMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get acknowledged => $composableBuilder(
    column: $table.acknowledged,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionTableTableOrderingComposer get sessionId {
    final $$SessionTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
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

class $$SessionInterruptionsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionInterruptionsTableTable> {
  $$SessionInterruptionsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get afterMessageId => $composableBuilder(
    column: $table.afterMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get acknowledged => $composableBuilder(
    column: $table.acknowledged,
    builder: (column) => column,
  );

  $$SessionTableTableAnnotationComposer get sessionId {
    final $$SessionTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
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

class $$SessionInterruptionsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionInterruptionsTableTable,
          SessionInterruptionDto,
          $$SessionInterruptionsTableTableFilterComposer,
          $$SessionInterruptionsTableTableOrderingComposer,
          $$SessionInterruptionsTableTableAnnotationComposer,
          $$SessionInterruptionsTableTableCreateCompanionBuilder,
          $$SessionInterruptionsTableTableUpdateCompanionBuilder,
          (SessionInterruptionDto, $$SessionInterruptionsTableTableReferences),
          SessionInterruptionDto,
          PrefetchHooks Function({bool sessionId})
        > {
  $$SessionInterruptionsTableTableTableManager(
    _$AppDatabase db,
    $SessionInterruptionsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionInterruptionsTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SessionInterruptionsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SessionInterruptionsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<String> afterMessageId = const Value.absent(),
                Value<bool> acknowledged = const Value.absent(),
              }) => SessionInterruptionsTableCompanion(
                sessionId: sessionId,
                afterMessageId: afterMessageId,
                acknowledged: acknowledged,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required String afterMessageId,
                required bool acknowledged,
              }) => SessionInterruptionsTableCompanion.insert(
                sessionId: sessionId,
                afterMessageId: afterMessageId,
                acknowledged: acknowledged,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $SessionInterruptionsTableTable,
                    SessionInterruptionDto
                  >(table),
                  $$SessionInterruptionsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
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
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable:
                            $$SessionInterruptionsTableTableReferences
                                ._sessionIdTable(db),
                        referencedColumn:
                            $$SessionInterruptionsTableTableReferences
                                ._sessionIdTable(db)
                                .sessionId,
                      ) as T;
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

typedef $$SessionInterruptionsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionInterruptionsTableTable,
      SessionInterruptionDto,
      $$SessionInterruptionsTableTableFilterComposer,
      $$SessionInterruptionsTableTableOrderingComposer,
      $$SessionInterruptionsTableTableAnnotationComposer,
      $$SessionInterruptionsTableTableCreateCompanionBuilder,
      $$SessionInterruptionsTableTableUpdateCompanionBuilder,
      (SessionInterruptionDto, $$SessionInterruptionsTableTableReferences),
      SessionInterruptionDto,
      PrefetchHooks Function({bool sessionId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProjectsTableTableTableManager get projectsTable =>
      $$ProjectsTableTableTableManager(_db, _db.projectsTable);
  $$ScheduledTasksTableTableTableManager get scheduledTasksTable =>
      $$ScheduledTasksTableTableTableManager(_db, _db.scheduledTasksTable);
  $$SessionTableTableTableManager get sessionTable =>
      $$SessionTableTableTableManager(_db, _db.sessionTable);
  $$DeletedSessionsTableTableTableManager get deletedSessionsTable =>
      $$DeletedSessionsTableTableTableManager(_db, _db.deletedSessionsTable);
  $$CatalogHydrationsTableTableTableManager get catalogHydrationsTable =>
      $$CatalogHydrationsTableTableTableManager(
        _db,
        _db.catalogHydrationsTable,
      );
  $$SessionOptionsCacheTableTableTableManager get sessionOptionsCacheTable =>
      $$SessionOptionsCacheTableTableTableManager(
        _db,
        _db.sessionOptionsCacheTable,
      );
  $$NewSessionDefaultsTableTableTableManager get newSessionDefaultsTable =>
      $$NewSessionDefaultsTableTableTableManager(
        _db,
        _db.newSessionDefaultsTable,
      );
  $$AcceptedPromptsTableTableTableManager get acceptedPromptsTable =>
      $$AcceptedPromptsTableTableTableManager(_db, _db.acceptedPromptsTable);
  $$SessionContinuationTableTableTableManager get sessionContinuationTable =>
      $$SessionContinuationTableTableTableManager(
        _db,
        _db.sessionContinuationTable,
      );
  $$SideChatExchangesTableTableTableManager get sideChatExchangesTable =>
      $$SideChatExchangesTableTableTableManager(
        _db,
        _db.sideChatExchangesTable,
      );
  $$ScheduledTaskRunsTableTableTableManager get scheduledTaskRunsTable =>
      $$ScheduledTaskRunsTableTableTableManager(
        _db,
        _db.scheduledTaskRunsTable,
      );
  $$SessionRunningTurnsTableTableTableManager get sessionRunningTurnsTable =>
      $$SessionRunningTurnsTableTableTableManager(
        _db,
        _db.sessionRunningTurnsTable,
      );
  $$SessionInterruptionsTableTableTableManager get sessionInterruptionsTable =>
      $$SessionInterruptionsTableTableTableManager(
        _db,
        _db.sessionInterruptionsTable,
      );
}
