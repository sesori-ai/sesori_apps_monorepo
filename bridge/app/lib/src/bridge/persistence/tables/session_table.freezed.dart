// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_table.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SessionDto {

 String get sessionId; String get backendSessionId; String get projectId; String? get parentSessionId; String get directory; String? get worktreePath; String? get branchName; bool get isDedicated; int? get archivedAt; String? get baseBranch; String? get baseCommit; String? get lastAgent; AgentModel? get lastAgentModel; int get createdAt; int get updatedAt; int get projectionUpdatedAt; int? get lastActivityAt; int? get lastSeenAt; int? get lastUserMessageAt; String get pluginId; String? get title; String? get catalogTitle; int? get summaryAdditions; int? get summaryDeletions; int? get summaryFiles;
/// Create a copy of SessionDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionDtoCopyWith<SessionDto> get copyWith => _$SessionDtoCopyWithImpl<SessionDto>(this as SessionDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.backendSessionId, backendSessionId) || other.backendSessionId == backendSessionId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.parentSessionId, parentSessionId) || other.parentSessionId == parentSessionId)&&(identical(other.directory, directory) || other.directory == directory)&&(identical(other.worktreePath, worktreePath) || other.worktreePath == worktreePath)&&(identical(other.branchName, branchName) || other.branchName == branchName)&&(identical(other.isDedicated, isDedicated) || other.isDedicated == isDedicated)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.baseBranch, baseBranch) || other.baseBranch == baseBranch)&&(identical(other.baseCommit, baseCommit) || other.baseCommit == baseCommit)&&(identical(other.lastAgent, lastAgent) || other.lastAgent == lastAgent)&&(identical(other.lastAgentModel, lastAgentModel) || other.lastAgentModel == lastAgentModel)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.projectionUpdatedAt, projectionUpdatedAt) || other.projectionUpdatedAt == projectionUpdatedAt)&&(identical(other.lastActivityAt, lastActivityAt) || other.lastActivityAt == lastActivityAt)&&(identical(other.lastSeenAt, lastSeenAt) || other.lastSeenAt == lastSeenAt)&&(identical(other.lastUserMessageAt, lastUserMessageAt) || other.lastUserMessageAt == lastUserMessageAt)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.title, title) || other.title == title)&&(identical(other.catalogTitle, catalogTitle) || other.catalogTitle == catalogTitle)&&(identical(other.summaryAdditions, summaryAdditions) || other.summaryAdditions == summaryAdditions)&&(identical(other.summaryDeletions, summaryDeletions) || other.summaryDeletions == summaryDeletions)&&(identical(other.summaryFiles, summaryFiles) || other.summaryFiles == summaryFiles));
}


@override
int get hashCode => Object.hashAll([runtimeType,sessionId,backendSessionId,projectId,parentSessionId,directory,worktreePath,branchName,isDedicated,archivedAt,baseBranch,baseCommit,lastAgent,lastAgentModel,createdAt,updatedAt,projectionUpdatedAt,lastActivityAt,lastSeenAt,lastUserMessageAt,pluginId,title,catalogTitle,summaryAdditions,summaryDeletions,summaryFiles]);

@override
String toString() {
  return 'SessionDto(sessionId: $sessionId, backendSessionId: $backendSessionId, projectId: $projectId, parentSessionId: $parentSessionId, directory: $directory, worktreePath: $worktreePath, branchName: $branchName, isDedicated: $isDedicated, archivedAt: $archivedAt, baseBranch: $baseBranch, baseCommit: $baseCommit, lastAgent: $lastAgent, lastAgentModel: $lastAgentModel, createdAt: $createdAt, updatedAt: $updatedAt, projectionUpdatedAt: $projectionUpdatedAt, lastActivityAt: $lastActivityAt, lastSeenAt: $lastSeenAt, lastUserMessageAt: $lastUserMessageAt, pluginId: $pluginId, title: $title, catalogTitle: $catalogTitle, summaryAdditions: $summaryAdditions, summaryDeletions: $summaryDeletions, summaryFiles: $summaryFiles)';
}


}

/// @nodoc
abstract mixin class $SessionDtoCopyWith<$Res>  {
  factory $SessionDtoCopyWith(SessionDto value, $Res Function(SessionDto) _then) = _$SessionDtoCopyWithImpl;
@useResult
$Res call({
 String sessionId, String backendSessionId, String projectId, String? parentSessionId, String directory, String? worktreePath, String? branchName, bool isDedicated, int? archivedAt, String? baseBranch, String? baseCommit, String? lastAgent, AgentModel? lastAgentModel, int createdAt, int updatedAt, int projectionUpdatedAt, int? lastActivityAt, int? lastSeenAt, int? lastUserMessageAt, String pluginId, String? title, String? catalogTitle, int? summaryAdditions, int? summaryDeletions, int? summaryFiles
});


$AgentModelCopyWith<$Res>? get lastAgentModel;

}
/// @nodoc
class _$SessionDtoCopyWithImpl<$Res>
    implements $SessionDtoCopyWith<$Res> {
  _$SessionDtoCopyWithImpl(this._self, this._then);

  final SessionDto _self;
  final $Res Function(SessionDto) _then;

/// Create a copy of SessionDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? backendSessionId = null,Object? projectId = null,Object? parentSessionId = freezed,Object? directory = null,Object? worktreePath = freezed,Object? branchName = freezed,Object? isDedicated = null,Object? archivedAt = freezed,Object? baseBranch = freezed,Object? baseCommit = freezed,Object? lastAgent = freezed,Object? lastAgentModel = freezed,Object? createdAt = null,Object? updatedAt = null,Object? projectionUpdatedAt = null,Object? lastActivityAt = freezed,Object? lastSeenAt = freezed,Object? lastUserMessageAt = freezed,Object? pluginId = null,Object? title = freezed,Object? catalogTitle = freezed,Object? summaryAdditions = freezed,Object? summaryDeletions = freezed,Object? summaryFiles = freezed,}) {
  return _then(_self.copyWith(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,backendSessionId: null == backendSessionId ? _self.backendSessionId : backendSessionId // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,parentSessionId: freezed == parentSessionId ? _self.parentSessionId : parentSessionId // ignore: cast_nullable_to_non_nullable
as String?,directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,worktreePath: freezed == worktreePath ? _self.worktreePath : worktreePath // ignore: cast_nullable_to_non_nullable
as String?,branchName: freezed == branchName ? _self.branchName : branchName // ignore: cast_nullable_to_non_nullable
as String?,isDedicated: null == isDedicated ? _self.isDedicated : isDedicated // ignore: cast_nullable_to_non_nullable
as bool,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int?,baseBranch: freezed == baseBranch ? _self.baseBranch : baseBranch // ignore: cast_nullable_to_non_nullable
as String?,baseCommit: freezed == baseCommit ? _self.baseCommit : baseCommit // ignore: cast_nullable_to_non_nullable
as String?,lastAgent: freezed == lastAgent ? _self.lastAgent : lastAgent // ignore: cast_nullable_to_non_nullable
as String?,lastAgentModel: freezed == lastAgentModel ? _self.lastAgentModel : lastAgentModel // ignore: cast_nullable_to_non_nullable
as AgentModel?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,projectionUpdatedAt: null == projectionUpdatedAt ? _self.projectionUpdatedAt : projectionUpdatedAt // ignore: cast_nullable_to_non_nullable
as int,lastActivityAt: freezed == lastActivityAt ? _self.lastActivityAt : lastActivityAt // ignore: cast_nullable_to_non_nullable
as int?,lastSeenAt: freezed == lastSeenAt ? _self.lastSeenAt : lastSeenAt // ignore: cast_nullable_to_non_nullable
as int?,lastUserMessageAt: freezed == lastUserMessageAt ? _self.lastUserMessageAt : lastUserMessageAt // ignore: cast_nullable_to_non_nullable
as int?,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,catalogTitle: freezed == catalogTitle ? _self.catalogTitle : catalogTitle // ignore: cast_nullable_to_non_nullable
as String?,summaryAdditions: freezed == summaryAdditions ? _self.summaryAdditions : summaryAdditions // ignore: cast_nullable_to_non_nullable
as int?,summaryDeletions: freezed == summaryDeletions ? _self.summaryDeletions : summaryDeletions // ignore: cast_nullable_to_non_nullable
as int?,summaryFiles: freezed == summaryFiles ? _self.summaryFiles : summaryFiles // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of SessionDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentModelCopyWith<$Res>? get lastAgentModel {
    if (_self.lastAgentModel == null) {
    return null;
  }

  return $AgentModelCopyWith<$Res>(_self.lastAgentModel!, (value) {
    return _then(_self.copyWith(lastAgentModel: value));
  });
}
}



/// @nodoc


class _SessionDto extends SessionDto {
  const _SessionDto({required this.sessionId, required this.backendSessionId, required this.projectId, required this.parentSessionId, required this.directory, required this.worktreePath, required this.branchName, required this.isDedicated, required this.archivedAt, required this.baseBranch, required this.baseCommit, required this.lastAgent, required this.lastAgentModel, required this.createdAt, required this.updatedAt, required this.projectionUpdatedAt, required this.lastActivityAt, required this.lastSeenAt, required this.lastUserMessageAt, required this.pluginId, required this.title, required this.catalogTitle, required this.summaryAdditions, required this.summaryDeletions, required this.summaryFiles}): super._();
  

@override final  String sessionId;
@override final  String backendSessionId;
@override final  String projectId;
@override final  String? parentSessionId;
@override final  String directory;
@override final  String? worktreePath;
@override final  String? branchName;
@override final  bool isDedicated;
@override final  int? archivedAt;
@override final  String? baseBranch;
@override final  String? baseCommit;
@override final  String? lastAgent;
@override final  AgentModel? lastAgentModel;
@override final  int createdAt;
@override final  int updatedAt;
@override final  int projectionUpdatedAt;
@override final  int? lastActivityAt;
@override final  int? lastSeenAt;
@override final  int? lastUserMessageAt;
@override final  String pluginId;
@override final  String? title;
@override final  String? catalogTitle;
@override final  int? summaryAdditions;
@override final  int? summaryDeletions;
@override final  int? summaryFiles;

/// Create a copy of SessionDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionDtoCopyWith<_SessionDto> get copyWith => __$SessionDtoCopyWithImpl<_SessionDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.backendSessionId, backendSessionId) || other.backendSessionId == backendSessionId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.parentSessionId, parentSessionId) || other.parentSessionId == parentSessionId)&&(identical(other.directory, directory) || other.directory == directory)&&(identical(other.worktreePath, worktreePath) || other.worktreePath == worktreePath)&&(identical(other.branchName, branchName) || other.branchName == branchName)&&(identical(other.isDedicated, isDedicated) || other.isDedicated == isDedicated)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.baseBranch, baseBranch) || other.baseBranch == baseBranch)&&(identical(other.baseCommit, baseCommit) || other.baseCommit == baseCommit)&&(identical(other.lastAgent, lastAgent) || other.lastAgent == lastAgent)&&(identical(other.lastAgentModel, lastAgentModel) || other.lastAgentModel == lastAgentModel)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.projectionUpdatedAt, projectionUpdatedAt) || other.projectionUpdatedAt == projectionUpdatedAt)&&(identical(other.lastActivityAt, lastActivityAt) || other.lastActivityAt == lastActivityAt)&&(identical(other.lastSeenAt, lastSeenAt) || other.lastSeenAt == lastSeenAt)&&(identical(other.lastUserMessageAt, lastUserMessageAt) || other.lastUserMessageAt == lastUserMessageAt)&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.title, title) || other.title == title)&&(identical(other.catalogTitle, catalogTitle) || other.catalogTitle == catalogTitle)&&(identical(other.summaryAdditions, summaryAdditions) || other.summaryAdditions == summaryAdditions)&&(identical(other.summaryDeletions, summaryDeletions) || other.summaryDeletions == summaryDeletions)&&(identical(other.summaryFiles, summaryFiles) || other.summaryFiles == summaryFiles));
}


@override
int get hashCode => Object.hashAll([runtimeType,sessionId,backendSessionId,projectId,parentSessionId,directory,worktreePath,branchName,isDedicated,archivedAt,baseBranch,baseCommit,lastAgent,lastAgentModel,createdAt,updatedAt,projectionUpdatedAt,lastActivityAt,lastSeenAt,lastUserMessageAt,pluginId,title,catalogTitle,summaryAdditions,summaryDeletions,summaryFiles]);

@override
String toString() {
  return 'SessionDto(sessionId: $sessionId, backendSessionId: $backendSessionId, projectId: $projectId, parentSessionId: $parentSessionId, directory: $directory, worktreePath: $worktreePath, branchName: $branchName, isDedicated: $isDedicated, archivedAt: $archivedAt, baseBranch: $baseBranch, baseCommit: $baseCommit, lastAgent: $lastAgent, lastAgentModel: $lastAgentModel, createdAt: $createdAt, updatedAt: $updatedAt, projectionUpdatedAt: $projectionUpdatedAt, lastActivityAt: $lastActivityAt, lastSeenAt: $lastSeenAt, lastUserMessageAt: $lastUserMessageAt, pluginId: $pluginId, title: $title, catalogTitle: $catalogTitle, summaryAdditions: $summaryAdditions, summaryDeletions: $summaryDeletions, summaryFiles: $summaryFiles)';
}


}

/// @nodoc
abstract mixin class _$SessionDtoCopyWith<$Res> implements $SessionDtoCopyWith<$Res> {
  factory _$SessionDtoCopyWith(_SessionDto value, $Res Function(_SessionDto) _then) = __$SessionDtoCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, String backendSessionId, String projectId, String? parentSessionId, String directory, String? worktreePath, String? branchName, bool isDedicated, int? archivedAt, String? baseBranch, String? baseCommit, String? lastAgent, AgentModel? lastAgentModel, int createdAt, int updatedAt, int projectionUpdatedAt, int? lastActivityAt, int? lastSeenAt, int? lastUserMessageAt, String pluginId, String? title, String? catalogTitle, int? summaryAdditions, int? summaryDeletions, int? summaryFiles
});


@override $AgentModelCopyWith<$Res>? get lastAgentModel;

}
/// @nodoc
class __$SessionDtoCopyWithImpl<$Res>
    implements _$SessionDtoCopyWith<$Res> {
  __$SessionDtoCopyWithImpl(this._self, this._then);

  final _SessionDto _self;
  final $Res Function(_SessionDto) _then;

/// Create a copy of SessionDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? backendSessionId = null,Object? projectId = null,Object? parentSessionId = freezed,Object? directory = null,Object? worktreePath = freezed,Object? branchName = freezed,Object? isDedicated = null,Object? archivedAt = freezed,Object? baseBranch = freezed,Object? baseCommit = freezed,Object? lastAgent = freezed,Object? lastAgentModel = freezed,Object? createdAt = null,Object? updatedAt = null,Object? projectionUpdatedAt = null,Object? lastActivityAt = freezed,Object? lastSeenAt = freezed,Object? lastUserMessageAt = freezed,Object? pluginId = null,Object? title = freezed,Object? catalogTitle = freezed,Object? summaryAdditions = freezed,Object? summaryDeletions = freezed,Object? summaryFiles = freezed,}) {
  return _then(_SessionDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,backendSessionId: null == backendSessionId ? _self.backendSessionId : backendSessionId // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,parentSessionId: freezed == parentSessionId ? _self.parentSessionId : parentSessionId // ignore: cast_nullable_to_non_nullable
as String?,directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,worktreePath: freezed == worktreePath ? _self.worktreePath : worktreePath // ignore: cast_nullable_to_non_nullable
as String?,branchName: freezed == branchName ? _self.branchName : branchName // ignore: cast_nullable_to_non_nullable
as String?,isDedicated: null == isDedicated ? _self.isDedicated : isDedicated // ignore: cast_nullable_to_non_nullable
as bool,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int?,baseBranch: freezed == baseBranch ? _self.baseBranch : baseBranch // ignore: cast_nullable_to_non_nullable
as String?,baseCommit: freezed == baseCommit ? _self.baseCommit : baseCommit // ignore: cast_nullable_to_non_nullable
as String?,lastAgent: freezed == lastAgent ? _self.lastAgent : lastAgent // ignore: cast_nullable_to_non_nullable
as String?,lastAgentModel: freezed == lastAgentModel ? _self.lastAgentModel : lastAgentModel // ignore: cast_nullable_to_non_nullable
as AgentModel?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,projectionUpdatedAt: null == projectionUpdatedAt ? _self.projectionUpdatedAt : projectionUpdatedAt // ignore: cast_nullable_to_non_nullable
as int,lastActivityAt: freezed == lastActivityAt ? _self.lastActivityAt : lastActivityAt // ignore: cast_nullable_to_non_nullable
as int?,lastSeenAt: freezed == lastSeenAt ? _self.lastSeenAt : lastSeenAt // ignore: cast_nullable_to_non_nullable
as int?,lastUserMessageAt: freezed == lastUserMessageAt ? _self.lastUserMessageAt : lastUserMessageAt // ignore: cast_nullable_to_non_nullable
as int?,pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,catalogTitle: freezed == catalogTitle ? _self.catalogTitle : catalogTitle // ignore: cast_nullable_to_non_nullable
as String?,summaryAdditions: freezed == summaryAdditions ? _self.summaryAdditions : summaryAdditions // ignore: cast_nullable_to_non_nullable
as int?,summaryDeletions: freezed == summaryDeletions ? _self.summaryDeletions : summaryDeletions // ignore: cast_nullable_to_non_nullable
as int?,summaryFiles: freezed == summaryFiles ? _self.summaryFiles : summaryFiles // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of SessionDto
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AgentModelCopyWith<$Res>? get lastAgentModel {
    if (_self.lastAgentModel == null) {
    return null;
  }

  return $AgentModelCopyWith<$Res>(_self.lastAgentModel!, (value) {
    return _then(_self.copyWith(lastAgentModel: value));
  });
}
}

// dart format on
