// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pull_request_monitor_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PullRequestMonitorConfig {

/// Whether a watch started without choosing auto-merge gets it.
 bool get autoMerge;/// Repositories whose own setting replaces [autoMerge], by lowercased
/// `owner/repo`.
 Map<String, bool> get repositoryAutoMerge;/// How long a report waits after the latest activity, so a burst arrives
/// as one report.
 int get quietMinutes;/// How long a due report waits for running CI before it goes out anyway.
 int get ciWaitMinutes;/// How long an open PR stays still before its watchers are reminded of
/// it; 0 sends no reminders.
 int get idleReminderMinutes;
/// Create a copy of PullRequestMonitorConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PullRequestMonitorConfigCopyWith<PullRequestMonitorConfig> get copyWith => _$PullRequestMonitorConfigCopyWithImpl<PullRequestMonitorConfig>(this as PullRequestMonitorConfig, _$identity);

  /// Serializes this PullRequestMonitorConfig to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PullRequestMonitorConfig;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestMonitorConfig&&(identical(other.autoMerge, _this.autoMerge) || other.autoMerge == _this.autoMerge)&&const DeepCollectionEquality().equals(other.repositoryAutoMerge, _this.repositoryAutoMerge)&&(identical(other.quietMinutes, _this.quietMinutes) || other.quietMinutes == _this.quietMinutes)&&(identical(other.ciWaitMinutes, _this.ciWaitMinutes) || other.ciWaitMinutes == _this.ciWaitMinutes)&&(identical(other.idleReminderMinutes, _this.idleReminderMinutes) || other.idleReminderMinutes == _this.idleReminderMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PullRequestMonitorConfig;
  return Object.hash(runtimeType,_this.autoMerge,const DeepCollectionEquality().hash(_this.repositoryAutoMerge),_this.quietMinutes,_this.ciWaitMinutes,_this.idleReminderMinutes);
}

@override
String toString() {
  final _this = this as PullRequestMonitorConfig;
  return 'PullRequestMonitorConfig(autoMerge: ${_this.autoMerge}, repositoryAutoMerge: ${_this.repositoryAutoMerge}, quietMinutes: ${_this.quietMinutes}, ciWaitMinutes: ${_this.ciWaitMinutes}, idleReminderMinutes: ${_this.idleReminderMinutes})';
}


}

/// @nodoc
abstract mixin class $PullRequestMonitorConfigCopyWith<$Res>  {
  factory $PullRequestMonitorConfigCopyWith(PullRequestMonitorConfig value, $Res Function(PullRequestMonitorConfig) _then) = _$PullRequestMonitorConfigCopyWithImpl;
@useResult
$Res call({
 bool autoMerge, Map<String, bool> repositoryAutoMerge, int quietMinutes, int ciWaitMinutes, int idleReminderMinutes
});




}
/// @nodoc
class _$PullRequestMonitorConfigCopyWithImpl<$Res>
    implements $PullRequestMonitorConfigCopyWith<$Res> {
  _$PullRequestMonitorConfigCopyWithImpl(this._self, this._then);

  final PullRequestMonitorConfig _self;
  final $Res Function(PullRequestMonitorConfig) _then;

/// Create a copy of PullRequestMonitorConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? autoMerge = null,Object? repositoryAutoMerge = null,Object? quietMinutes = null,Object? ciWaitMinutes = null,Object? idleReminderMinutes = null,}) {
  return _then(PullRequestMonitorConfig(
autoMerge: null == autoMerge ? _self.autoMerge : autoMerge // ignore: cast_nullable_to_non_nullable
as bool,repositoryAutoMerge: null == repositoryAutoMerge ? _self.repositoryAutoMerge : repositoryAutoMerge // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,quietMinutes: null == quietMinutes ? _self.quietMinutes : quietMinutes // ignore: cast_nullable_to_non_nullable
as int,ciWaitMinutes: null == ciWaitMinutes ? _self.ciWaitMinutes : ciWaitMinutes // ignore: cast_nullable_to_non_nullable
as int,idleReminderMinutes: null == idleReminderMinutes ? _self.idleReminderMinutes : idleReminderMinutes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PullRequestMonitorConfig extends PullRequestMonitorConfig {
  const _PullRequestMonitorConfig({required this.autoMerge, required  Map<String, bool> repositoryAutoMerge, required this.quietMinutes, required this.ciWaitMinutes, required this.idleReminderMinutes}): _repositoryAutoMerge = repositoryAutoMerge,super._();
  factory _PullRequestMonitorConfig.fromJson(Map<String, dynamic> json) => _$PullRequestMonitorConfigFromJson(json);

/// Whether a watch started without choosing auto-merge gets it.
@override final  bool autoMerge;
/// Repositories whose own setting replaces [autoMerge], by lowercased
/// `owner/repo`.
 final  Map<String, bool> _repositoryAutoMerge;
/// Repositories whose own setting replaces [autoMerge], by lowercased
/// `owner/repo`.
@override Map<String, bool> get repositoryAutoMerge {
  if (_repositoryAutoMerge is EqualUnmodifiableMapView) return _repositoryAutoMerge;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_repositoryAutoMerge);
}

/// How long a report waits after the latest activity, so a burst arrives
/// as one report.
@override final  int quietMinutes;
/// How long a due report waits for running CI before it goes out anyway.
@override final  int ciWaitMinutes;
/// How long an open PR stays still before its watchers are reminded of
/// it; 0 sends no reminders.
@override final  int idleReminderMinutes;

/// Create a copy of PullRequestMonitorConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PullRequestMonitorConfigCopyWith<_PullRequestMonitorConfig> get copyWith => __$PullRequestMonitorConfigCopyWithImpl<_PullRequestMonitorConfig>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PullRequestMonitorConfigToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PullRequestMonitorConfig&&(identical(other.autoMerge, autoMerge) || other.autoMerge == autoMerge)&&const DeepCollectionEquality().equals(other.repositoryAutoMerge, _repositoryAutoMerge)&&(identical(other.quietMinutes, quietMinutes) || other.quietMinutes == quietMinutes)&&(identical(other.ciWaitMinutes, ciWaitMinutes) || other.ciWaitMinutes == ciWaitMinutes)&&(identical(other.idleReminderMinutes, idleReminderMinutes) || other.idleReminderMinutes == idleReminderMinutes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,autoMerge,const DeepCollectionEquality().hash(_repositoryAutoMerge),quietMinutes,ciWaitMinutes,idleReminderMinutes);
}

@override
String toString() {
    return 'PullRequestMonitorConfig(autoMerge: $autoMerge, repositoryAutoMerge: $repositoryAutoMerge, quietMinutes: $quietMinutes, ciWaitMinutes: $ciWaitMinutes, idleReminderMinutes: $idleReminderMinutes)';
}


}

/// @nodoc
abstract mixin class _$PullRequestMonitorConfigCopyWith<$Res> implements $PullRequestMonitorConfigCopyWith<$Res> {
  factory _$PullRequestMonitorConfigCopyWith(_PullRequestMonitorConfig value, $Res Function(_PullRequestMonitorConfig) _then) = __$PullRequestMonitorConfigCopyWithImpl;
@override @useResult
$Res call({
 bool autoMerge, Map<String, bool> repositoryAutoMerge, int quietMinutes, int ciWaitMinutes, int idleReminderMinutes
});




}
/// @nodoc
class __$PullRequestMonitorConfigCopyWithImpl<$Res>
    implements _$PullRequestMonitorConfigCopyWith<$Res> {
  __$PullRequestMonitorConfigCopyWithImpl(this._self, this._then);

  final _PullRequestMonitorConfig _self;
  final $Res Function(_PullRequestMonitorConfig) _then;

/// Create a copy of PullRequestMonitorConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? autoMerge = null,Object? repositoryAutoMerge = null,Object? quietMinutes = null,Object? ciWaitMinutes = null,Object? idleReminderMinutes = null,}) {
  return _then(_PullRequestMonitorConfig(
autoMerge: null == autoMerge ? _self.autoMerge : autoMerge // ignore: cast_nullable_to_non_nullable
as bool,repositoryAutoMerge: null == repositoryAutoMerge ? _self._repositoryAutoMerge : repositoryAutoMerge // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,quietMinutes: null == quietMinutes ? _self.quietMinutes : quietMinutes // ignore: cast_nullable_to_non_nullable
as int,ciWaitMinutes: null == ciWaitMinutes ? _self.ciWaitMinutes : ciWaitMinutes // ignore: cast_nullable_to_non_nullable
as int,idleReminderMinutes: null == idleReminderMinutes ? _self.idleReminderMinutes : idleReminderMinutes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
