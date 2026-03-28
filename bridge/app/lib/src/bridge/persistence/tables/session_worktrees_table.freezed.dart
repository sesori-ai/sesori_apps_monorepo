// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_worktrees_table.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SessionWorktree {

 String get sessionId; String get projectId; String get worktreePath; String get branchName;
/// Create a copy of SessionWorktree
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionWorktreeCopyWith<SessionWorktree> get copyWith => _$SessionWorktreeCopyWithImpl<SessionWorktree>(this as SessionWorktree, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionWorktree&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.worktreePath, worktreePath) || other.worktreePath == worktreePath)&&(identical(other.branchName, branchName) || other.branchName == branchName));
}


@override
int get hashCode => Object.hash(runtimeType,sessionId,projectId,worktreePath,branchName);

@override
String toString() {
  return 'SessionWorktree(sessionId: $sessionId, projectId: $projectId, worktreePath: $worktreePath, branchName: $branchName)';
}


}

/// @nodoc
abstract mixin class $SessionWorktreeCopyWith<$Res>  {
  factory $SessionWorktreeCopyWith(SessionWorktree value, $Res Function(SessionWorktree) _then) = _$SessionWorktreeCopyWithImpl;
@useResult
$Res call({
 String sessionId, String projectId, String worktreePath, String branchName
});




}
/// @nodoc
class _$SessionWorktreeCopyWithImpl<$Res>
    implements $SessionWorktreeCopyWith<$Res> {
  _$SessionWorktreeCopyWithImpl(this._self, this._then);

  final SessionWorktree _self;
  final $Res Function(SessionWorktree) _then;

/// Create a copy of SessionWorktree
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? projectId = null,Object? worktreePath = null,Object? branchName = null,}) {
  return _then(_self.copyWith(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,worktreePath: null == worktreePath ? _self.worktreePath : worktreePath // ignore: cast_nullable_to_non_nullable
as String,branchName: null == branchName ? _self.branchName : branchName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc


class _SessionWorktree extends SessionWorktree {
  const _SessionWorktree({required this.sessionId, required this.projectId, required this.worktreePath, required this.branchName}): super._();
  

@override final  String sessionId;
@override final  String projectId;
@override final  String worktreePath;
@override final  String branchName;

/// Create a copy of SessionWorktree
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionWorktreeCopyWith<_SessionWorktree> get copyWith => __$SessionWorktreeCopyWithImpl<_SessionWorktree>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionWorktree&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.worktreePath, worktreePath) || other.worktreePath == worktreePath)&&(identical(other.branchName, branchName) || other.branchName == branchName));
}


@override
int get hashCode => Object.hash(runtimeType,sessionId,projectId,worktreePath,branchName);

@override
String toString() {
  return 'SessionWorktree(sessionId: $sessionId, projectId: $projectId, worktreePath: $worktreePath, branchName: $branchName)';
}


}

/// @nodoc
abstract mixin class _$SessionWorktreeCopyWith<$Res> implements $SessionWorktreeCopyWith<$Res> {
  factory _$SessionWorktreeCopyWith(_SessionWorktree value, $Res Function(_SessionWorktree) _then) = __$SessionWorktreeCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, String projectId, String worktreePath, String branchName
});




}
/// @nodoc
class __$SessionWorktreeCopyWithImpl<$Res>
    implements _$SessionWorktreeCopyWith<$Res> {
  __$SessionWorktreeCopyWithImpl(this._self, this._then);

  final _SessionWorktree _self;
  final $Res Function(_SessionWorktree) _then;

/// Create a copy of SessionWorktree
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? projectId = null,Object? worktreePath = null,Object? branchName = null,}) {
  return _then(_SessionWorktree(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,worktreePath: null == worktreePath ? _self.worktreePath : worktreePath // ignore: cast_nullable_to_non_nullable
as String,branchName: null == branchName ? _self.branchName : branchName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
