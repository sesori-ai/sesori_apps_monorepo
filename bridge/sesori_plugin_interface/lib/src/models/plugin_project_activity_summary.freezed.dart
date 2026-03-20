// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_project_activity_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PluginProjectActivitySummary {

 String get worktree; int get activeSessions; List<String> get activeSessionIds;
/// Create a copy of PluginProjectActivitySummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginProjectActivitySummaryCopyWith<PluginProjectActivitySummary> get copyWith => _$PluginProjectActivitySummaryCopyWithImpl<PluginProjectActivitySummary>(this as PluginProjectActivitySummary, _$identity);

  /// Serializes this PluginProjectActivitySummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginProjectActivitySummary&&(identical(other.worktree, worktree) || other.worktree == worktree)&&(identical(other.activeSessions, activeSessions) || other.activeSessions == activeSessions)&&const DeepCollectionEquality().equals(other.activeSessionIds, activeSessionIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,worktree,activeSessions,const DeepCollectionEquality().hash(activeSessionIds));

@override
String toString() {
  return 'PluginProjectActivitySummary(worktree: $worktree, activeSessions: $activeSessions, activeSessionIds: $activeSessionIds)';
}


}

/// @nodoc
abstract mixin class $PluginProjectActivitySummaryCopyWith<$Res>  {
  factory $PluginProjectActivitySummaryCopyWith(PluginProjectActivitySummary value, $Res Function(PluginProjectActivitySummary) _then) = _$PluginProjectActivitySummaryCopyWithImpl;
@useResult
$Res call({
 String worktree, int activeSessions, List<String> activeSessionIds
});




}
/// @nodoc
class _$PluginProjectActivitySummaryCopyWithImpl<$Res>
    implements $PluginProjectActivitySummaryCopyWith<$Res> {
  _$PluginProjectActivitySummaryCopyWithImpl(this._self, this._then);

  final PluginProjectActivitySummary _self;
  final $Res Function(PluginProjectActivitySummary) _then;

/// Create a copy of PluginProjectActivitySummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? worktree = null,Object? activeSessions = null,Object? activeSessionIds = null,}) {
  return _then(_self.copyWith(
worktree: null == worktree ? _self.worktree : worktree // ignore: cast_nullable_to_non_nullable
as String,activeSessions: null == activeSessions ? _self.activeSessions : activeSessions // ignore: cast_nullable_to_non_nullable
as int,activeSessionIds: null == activeSessionIds ? _self.activeSessionIds : activeSessionIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginProjectActivitySummary implements PluginProjectActivitySummary {
  const _PluginProjectActivitySummary({required this.worktree, required this.activeSessions, final  List<String> activeSessionIds = const []}): _activeSessionIds = activeSessionIds;
  

@override final  String worktree;
@override final  int activeSessions;
 final  List<String> _activeSessionIds;
@override@JsonKey() List<String> get activeSessionIds {
  if (_activeSessionIds is EqualUnmodifiableListView) return _activeSessionIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_activeSessionIds);
}


/// Create a copy of PluginProjectActivitySummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginProjectActivitySummaryCopyWith<_PluginProjectActivitySummary> get copyWith => __$PluginProjectActivitySummaryCopyWithImpl<_PluginProjectActivitySummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginProjectActivitySummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginProjectActivitySummary&&(identical(other.worktree, worktree) || other.worktree == worktree)&&(identical(other.activeSessions, activeSessions) || other.activeSessions == activeSessions)&&const DeepCollectionEquality().equals(other._activeSessionIds, _activeSessionIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,worktree,activeSessions,const DeepCollectionEquality().hash(_activeSessionIds));

@override
String toString() {
  return 'PluginProjectActivitySummary(worktree: $worktree, activeSessions: $activeSessions, activeSessionIds: $activeSessionIds)';
}


}

/// @nodoc
abstract mixin class _$PluginProjectActivitySummaryCopyWith<$Res> implements $PluginProjectActivitySummaryCopyWith<$Res> {
  factory _$PluginProjectActivitySummaryCopyWith(_PluginProjectActivitySummary value, $Res Function(_PluginProjectActivitySummary) _then) = __$PluginProjectActivitySummaryCopyWithImpl;
@override @useResult
$Res call({
 String worktree, int activeSessions, List<String> activeSessionIds
});




}
/// @nodoc
class __$PluginProjectActivitySummaryCopyWithImpl<$Res>
    implements _$PluginProjectActivitySummaryCopyWith<$Res> {
  __$PluginProjectActivitySummaryCopyWithImpl(this._self, this._then);

  final _PluginProjectActivitySummary _self;
  final $Res Function(_PluginProjectActivitySummary) _then;

/// Create a copy of PluginProjectActivitySummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? worktree = null,Object? activeSessions = null,Object? activeSessionIds = null,}) {
  return _then(_PluginProjectActivitySummary(
worktree: null == worktree ? _self.worktree : worktree // ignore: cast_nullable_to_non_nullable
as String,activeSessions: null == activeSessions ? _self.activeSessions : activeSessions // ignore: cast_nullable_to_non_nullable
as int,activeSessionIds: null == activeSessionIds ? _self._activeSessionIds : activeSessionIds // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
