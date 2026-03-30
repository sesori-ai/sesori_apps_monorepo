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

 String get sessionId; String get projectId; String? get worktreePath; String? get branchName; bool get isDedicated; int? get archivedAt; String? get baseBranch; String? get baseCommit; int get createdAt;
/// Create a copy of SessionDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionDtoCopyWith<SessionDto> get copyWith => _$SessionDtoCopyWithImpl<SessionDto>(this as SessionDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.worktreePath, worktreePath) || other.worktreePath == worktreePath)&&(identical(other.branchName, branchName) || other.branchName == branchName)&&(identical(other.isDedicated, isDedicated) || other.isDedicated == isDedicated)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.baseBranch, baseBranch) || other.baseBranch == baseBranch)&&(identical(other.baseCommit, baseCommit) || other.baseCommit == baseCommit)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,sessionId,projectId,worktreePath,branchName,isDedicated,archivedAt,baseBranch,baseCommit,createdAt);

@override
String toString() {
  return 'SessionDto(sessionId: $sessionId, projectId: $projectId, worktreePath: $worktreePath, branchName: $branchName, isDedicated: $isDedicated, archivedAt: $archivedAt, baseBranch: $baseBranch, baseCommit: $baseCommit, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $SessionDtoCopyWith<$Res>  {
  factory $SessionDtoCopyWith(SessionDto value, $Res Function(SessionDto) _then) = _$SessionDtoCopyWithImpl;
@useResult
$Res call({
 String sessionId, String projectId, String? worktreePath, String? branchName, bool isDedicated, int? archivedAt, String? baseBranch, String? baseCommit, int createdAt
});




}
/// @nodoc
class _$SessionDtoCopyWithImpl<$Res>
    implements $SessionDtoCopyWith<$Res> {
  _$SessionDtoCopyWithImpl(this._self, this._then);

  final SessionDto _self;
  final $Res Function(SessionDto) _then;

/// Create a copy of SessionDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? projectId = null,Object? worktreePath = freezed,Object? branchName = freezed,Object? isDedicated = null,Object? archivedAt = freezed,Object? baseBranch = freezed,Object? baseCommit = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,worktreePath: freezed == worktreePath ? _self.worktreePath : worktreePath // ignore: cast_nullable_to_non_nullable
as String?,branchName: freezed == branchName ? _self.branchName : branchName // ignore: cast_nullable_to_non_nullable
as String?,isDedicated: null == isDedicated ? _self.isDedicated : isDedicated // ignore: cast_nullable_to_non_nullable
as bool,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int?,baseBranch: freezed == baseBranch ? _self.baseBranch : baseBranch // ignore: cast_nullable_to_non_nullable
as String?,baseCommit: freezed == baseCommit ? _self.baseCommit : baseCommit // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc


class _SessionDto extends SessionDto {
  const _SessionDto({required this.sessionId, required this.projectId, required this.worktreePath, required this.branchName, required this.isDedicated, required this.archivedAt, required this.baseBranch, required this.baseCommit, required this.createdAt}): super._();
  

@override final  String sessionId;
@override final  String projectId;
@override final  String? worktreePath;
@override final  String? branchName;
@override final  bool isDedicated;
@override final  int? archivedAt;
@override final  String? baseBranch;
@override final  String? baseCommit;
@override final  int createdAt;

/// Create a copy of SessionDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionDtoCopyWith<_SessionDto> get copyWith => __$SessionDtoCopyWithImpl<_SessionDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionDto&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.worktreePath, worktreePath) || other.worktreePath == worktreePath)&&(identical(other.branchName, branchName) || other.branchName == branchName)&&(identical(other.isDedicated, isDedicated) || other.isDedicated == isDedicated)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.baseBranch, baseBranch) || other.baseBranch == baseBranch)&&(identical(other.baseCommit, baseCommit) || other.baseCommit == baseCommit)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,sessionId,projectId,worktreePath,branchName,isDedicated,archivedAt,baseBranch,baseCommit,createdAt);

@override
String toString() {
  return 'SessionDto(sessionId: $sessionId, projectId: $projectId, worktreePath: $worktreePath, branchName: $branchName, isDedicated: $isDedicated, archivedAt: $archivedAt, baseBranch: $baseBranch, baseCommit: $baseCommit, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$SessionDtoCopyWith<$Res> implements $SessionDtoCopyWith<$Res> {
  factory _$SessionDtoCopyWith(_SessionDto value, $Res Function(_SessionDto) _then) = __$SessionDtoCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, String projectId, String? worktreePath, String? branchName, bool isDedicated, int? archivedAt, String? baseBranch, String? baseCommit, int createdAt
});




}
/// @nodoc
class __$SessionDtoCopyWithImpl<$Res>
    implements _$SessionDtoCopyWith<$Res> {
  __$SessionDtoCopyWithImpl(this._self, this._then);

  final _SessionDto _self;
  final $Res Function(_SessionDto) _then;

/// Create a copy of SessionDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? projectId = null,Object? worktreePath = freezed,Object? branchName = freezed,Object? isDedicated = null,Object? archivedAt = freezed,Object? baseBranch = freezed,Object? baseCommit = freezed,Object? createdAt = null,}) {
  return _then(_SessionDto(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,worktreePath: freezed == worktreePath ? _self.worktreePath : worktreePath // ignore: cast_nullable_to_non_nullable
as String?,branchName: freezed == branchName ? _self.branchName : branchName // ignore: cast_nullable_to_non_nullable
as String?,isDedicated: null == isDedicated ? _self.isDedicated : isDedicated // ignore: cast_nullable_to_non_nullable
as bool,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int?,baseBranch: freezed == baseBranch ? _self.baseBranch : baseBranch // ignore: cast_nullable_to_non_nullable
as String?,baseCommit: freezed == baseCommit ? _self.baseCommit : baseCommit // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
