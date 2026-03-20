// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project_activity_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProjectActivitySummary {

 String get worktree; int get activeSessions;
/// Create a copy of ProjectActivitySummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectActivitySummaryCopyWith<ProjectActivitySummary> get copyWith => _$ProjectActivitySummaryCopyWithImpl<ProjectActivitySummary>(this as ProjectActivitySummary, _$identity);

  /// Serializes this ProjectActivitySummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProjectActivitySummary&&(identical(other.worktree, worktree) || other.worktree == worktree)&&(identical(other.activeSessions, activeSessions) || other.activeSessions == activeSessions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,worktree,activeSessions);

@override
String toString() {
  return 'ProjectActivitySummary(worktree: $worktree, activeSessions: $activeSessions)';
}


}

/// @nodoc
abstract mixin class $ProjectActivitySummaryCopyWith<$Res>  {
  factory $ProjectActivitySummaryCopyWith(ProjectActivitySummary value, $Res Function(ProjectActivitySummary) _then) = _$ProjectActivitySummaryCopyWithImpl;
@useResult
$Res call({
 String worktree, int activeSessions
});




}
/// @nodoc
class _$ProjectActivitySummaryCopyWithImpl<$Res>
    implements $ProjectActivitySummaryCopyWith<$Res> {
  _$ProjectActivitySummaryCopyWithImpl(this._self, this._then);

  final ProjectActivitySummary _self;
  final $Res Function(ProjectActivitySummary) _then;

/// Create a copy of ProjectActivitySummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? worktree = null,Object? activeSessions = null,}) {
  return _then(_self.copyWith(
worktree: null == worktree ? _self.worktree : worktree // ignore: cast_nullable_to_non_nullable
as String,activeSessions: null == activeSessions ? _self.activeSessions : activeSessions // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _ProjectActivitySummary implements ProjectActivitySummary {
  const _ProjectActivitySummary({required this.worktree, this.activeSessions = 0});
  factory _ProjectActivitySummary.fromJson(Map<String, dynamic> json) => _$ProjectActivitySummaryFromJson(json);

@override final  String worktree;
@override@JsonKey() final  int activeSessions;

/// Create a copy of ProjectActivitySummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectActivitySummaryCopyWith<_ProjectActivitySummary> get copyWith => __$ProjectActivitySummaryCopyWithImpl<_ProjectActivitySummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectActivitySummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProjectActivitySummary&&(identical(other.worktree, worktree) || other.worktree == worktree)&&(identical(other.activeSessions, activeSessions) || other.activeSessions == activeSessions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,worktree,activeSessions);

@override
String toString() {
  return 'ProjectActivitySummary(worktree: $worktree, activeSessions: $activeSessions)';
}


}

/// @nodoc
abstract mixin class _$ProjectActivitySummaryCopyWith<$Res> implements $ProjectActivitySummaryCopyWith<$Res> {
  factory _$ProjectActivitySummaryCopyWith(_ProjectActivitySummary value, $Res Function(_ProjectActivitySummary) _then) = __$ProjectActivitySummaryCopyWithImpl;
@override @useResult
$Res call({
 String worktree, int activeSessions
});




}
/// @nodoc
class __$ProjectActivitySummaryCopyWithImpl<$Res>
    implements _$ProjectActivitySummaryCopyWith<$Res> {
  __$ProjectActivitySummaryCopyWithImpl(this._self, this._then);

  final _ProjectActivitySummary _self;
  final $Res Function(_ProjectActivitySummary) _then;

/// Create a copy of ProjectActivitySummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? worktree = null,Object? activeSessions = null,}) {
  return _then(_ProjectActivitySummary(
worktree: null == worktree ? _self.worktree : worktree // ignore: cast_nullable_to_non_nullable
as String,activeSessions: null == activeSessions ? _self.activeSessions : activeSessions // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
