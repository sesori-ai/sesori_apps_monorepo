// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_interruption.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SessionInterruption {

/// The newest stored message of the session when the bridge recorded the
/// interruption: the cut-off turn ends after it.
 String get afterMessageId;/// True until the user opens the session or sends something to it.
 bool get unacknowledged;
/// Create a copy of SessionInterruption
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionInterruptionCopyWith<SessionInterruption> get copyWith => _$SessionInterruptionCopyWithImpl<SessionInterruption>(this as SessionInterruption, _$identity);

  /// Serializes this SessionInterruption to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SessionInterruption;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionInterruption&&(identical(other.afterMessageId, _this.afterMessageId) || other.afterMessageId == _this.afterMessageId)&&(identical(other.unacknowledged, _this.unacknowledged) || other.unacknowledged == _this.unacknowledged));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SessionInterruption;
  return Object.hash(runtimeType,_this.afterMessageId,_this.unacknowledged);
}

@override
String toString() {
  final _this = this as SessionInterruption;
  return 'SessionInterruption(afterMessageId: ${_this.afterMessageId}, unacknowledged: ${_this.unacknowledged})';
}


}

/// @nodoc
abstract mixin class $SessionInterruptionCopyWith<$Res>  {
  factory $SessionInterruptionCopyWith(SessionInterruption value, $Res Function(SessionInterruption) _then) = _$SessionInterruptionCopyWithImpl;
@useResult
$Res call({
 String afterMessageId, bool unacknowledged
});




}
/// @nodoc
class _$SessionInterruptionCopyWithImpl<$Res>
    implements $SessionInterruptionCopyWith<$Res> {
  _$SessionInterruptionCopyWithImpl(this._self, this._then);

  final SessionInterruption _self;
  final $Res Function(SessionInterruption) _then;

/// Create a copy of SessionInterruption
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? afterMessageId = null,Object? unacknowledged = null,}) {
  return _then(SessionInterruption(
afterMessageId: null == afterMessageId ? _self.afterMessageId : afterMessageId // ignore: cast_nullable_to_non_nullable
as String,unacknowledged: null == unacknowledged ? _self.unacknowledged : unacknowledged // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SessionInterruption implements SessionInterruption {
  const _SessionInterruption({required this.afterMessageId, required this.unacknowledged});
  factory _SessionInterruption.fromJson(Map<String, dynamic> json) => _$SessionInterruptionFromJson(json);

/// The newest stored message of the session when the bridge recorded the
/// interruption: the cut-off turn ends after it.
@override final  String afterMessageId;
/// True until the user opens the session or sends something to it.
@override final  bool unacknowledged;

/// Create a copy of SessionInterruption
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionInterruptionCopyWith<_SessionInterruption> get copyWith => __$SessionInterruptionCopyWithImpl<_SessionInterruption>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionInterruptionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionInterruption&&(identical(other.afterMessageId, afterMessageId) || other.afterMessageId == afterMessageId)&&(identical(other.unacknowledged, unacknowledged) || other.unacknowledged == unacknowledged));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,afterMessageId,unacknowledged);
}

@override
String toString() {
    return 'SessionInterruption(afterMessageId: $afterMessageId, unacknowledged: $unacknowledged)';
}


}

/// @nodoc
abstract mixin class _$SessionInterruptionCopyWith<$Res> implements $SessionInterruptionCopyWith<$Res> {
  factory _$SessionInterruptionCopyWith(_SessionInterruption value, $Res Function(_SessionInterruption) _then) = __$SessionInterruptionCopyWithImpl;
@override @useResult
$Res call({
 String afterMessageId, bool unacknowledged
});




}
/// @nodoc
class __$SessionInterruptionCopyWithImpl<$Res>
    implements _$SessionInterruptionCopyWith<$Res> {
  __$SessionInterruptionCopyWithImpl(this._self, this._then);

  final _SessionInterruption _self;
  final $Res Function(_SessionInterruption) _then;

/// Create a copy of SessionInterruption
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? afterMessageId = null,Object? unacknowledged = null,}) {
  return _then(_SessionInterruption(
afterMessageId: null == afterMessageId ? _self.afterMessageId : afterMessageId // ignore: cast_nullable_to_non_nullable
as String,unacknowledged: null == unacknowledged ? _self.unacknowledged : unacknowledged // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
