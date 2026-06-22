// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'update_attempt.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UpdateAttempt {

/// The version the bridge was running when the attempt started.
 String get fromVersion;/// The version the attempt is moving to.
 String get toVersion;/// When the attempt began.
 DateTime get startedAt;/// The furthest pipeline stage the attempt reached.
 UpdateStage get stage;/// The attempt's current lifecycle status.
 UpdateAttemptStatus get status;/// Human-readable cause when [status] is [UpdateAttemptStatus.failed], else
/// `null`.
 String? get reason;
/// Create a copy of UpdateAttempt
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UpdateAttemptCopyWith<UpdateAttempt> get copyWith => _$UpdateAttemptCopyWithImpl<UpdateAttempt>(this as UpdateAttempt, _$identity);

  /// Serializes this UpdateAttempt to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UpdateAttempt&&(identical(other.fromVersion, fromVersion) || other.fromVersion == fromVersion)&&(identical(other.toVersion, toVersion) || other.toVersion == toVersion)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.stage, stage) || other.stage == stage)&&(identical(other.status, status) || other.status == status)&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fromVersion,toVersion,startedAt,stage,status,reason);

@override
String toString() {
  return 'UpdateAttempt(fromVersion: $fromVersion, toVersion: $toVersion, startedAt: $startedAt, stage: $stage, status: $status, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $UpdateAttemptCopyWith<$Res>  {
  factory $UpdateAttemptCopyWith(UpdateAttempt value, $Res Function(UpdateAttempt) _then) = _$UpdateAttemptCopyWithImpl;
@useResult
$Res call({
 String fromVersion, String toVersion, DateTime startedAt, UpdateStage stage, UpdateAttemptStatus status, String? reason
});




}
/// @nodoc
class _$UpdateAttemptCopyWithImpl<$Res>
    implements $UpdateAttemptCopyWith<$Res> {
  _$UpdateAttemptCopyWithImpl(this._self, this._then);

  final UpdateAttempt _self;
  final $Res Function(UpdateAttempt) _then;

/// Create a copy of UpdateAttempt
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fromVersion = null,Object? toVersion = null,Object? startedAt = null,Object? stage = null,Object? status = null,Object? reason = freezed,}) {
  return _then(_self.copyWith(
fromVersion: null == fromVersion ? _self.fromVersion : fromVersion // ignore: cast_nullable_to_non_nullable
as String,toVersion: null == toVersion ? _self.toVersion : toVersion // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,stage: null == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as UpdateStage,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as UpdateAttemptStatus,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _UpdateAttempt implements UpdateAttempt {
  const _UpdateAttempt({required this.fromVersion, required this.toVersion, required this.startedAt, required this.stage, required this.status, required this.reason});
  factory _UpdateAttempt.fromJson(Map<String, dynamic> json) => _$UpdateAttemptFromJson(json);

/// The version the bridge was running when the attempt started.
@override final  String fromVersion;
/// The version the attempt is moving to.
@override final  String toVersion;
/// When the attempt began.
@override final  DateTime startedAt;
/// The furthest pipeline stage the attempt reached.
@override final  UpdateStage stage;
/// The attempt's current lifecycle status.
@override final  UpdateAttemptStatus status;
/// Human-readable cause when [status] is [UpdateAttemptStatus.failed], else
/// `null`.
@override final  String? reason;

/// Create a copy of UpdateAttempt
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UpdateAttemptCopyWith<_UpdateAttempt> get copyWith => __$UpdateAttemptCopyWithImpl<_UpdateAttempt>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UpdateAttemptToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UpdateAttempt&&(identical(other.fromVersion, fromVersion) || other.fromVersion == fromVersion)&&(identical(other.toVersion, toVersion) || other.toVersion == toVersion)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.stage, stage) || other.stage == stage)&&(identical(other.status, status) || other.status == status)&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fromVersion,toVersion,startedAt,stage,status,reason);

@override
String toString() {
  return 'UpdateAttempt(fromVersion: $fromVersion, toVersion: $toVersion, startedAt: $startedAt, stage: $stage, status: $status, reason: $reason)';
}


}

/// @nodoc
abstract mixin class _$UpdateAttemptCopyWith<$Res> implements $UpdateAttemptCopyWith<$Res> {
  factory _$UpdateAttemptCopyWith(_UpdateAttempt value, $Res Function(_UpdateAttempt) _then) = __$UpdateAttemptCopyWithImpl;
@override @useResult
$Res call({
 String fromVersion, String toVersion, DateTime startedAt, UpdateStage stage, UpdateAttemptStatus status, String? reason
});




}
/// @nodoc
class __$UpdateAttemptCopyWithImpl<$Res>
    implements _$UpdateAttemptCopyWith<$Res> {
  __$UpdateAttemptCopyWithImpl(this._self, this._then);

  final _UpdateAttempt _self;
  final $Res Function(_UpdateAttempt) _then;

/// Create a copy of UpdateAttempt
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fromVersion = null,Object? toVersion = null,Object? startedAt = null,Object? stage = null,Object? status = null,Object? reason = freezed,}) {
  return _then(_UpdateAttempt(
fromVersion: null == fromVersion ? _self.fromVersion : fromVersion // ignore: cast_nullable_to_non_nullable
as String,toVersion: null == toVersion ? _self.toVersion : toVersion // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,stage: null == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as UpdateStage,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as UpdateAttemptStatus,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
