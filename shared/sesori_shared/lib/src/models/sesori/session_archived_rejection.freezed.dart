// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_archived_rejection.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SessionArchivedRejection {

 String get sessionId; SessionArchivedReason get reason;
/// Create a copy of SessionArchivedRejection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionArchivedRejectionCopyWith<SessionArchivedRejection> get copyWith => _$SessionArchivedRejectionCopyWithImpl<SessionArchivedRejection>(this as SessionArchivedRejection, _$identity);

  /// Serializes this SessionArchivedRejection to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionArchivedRejection&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,reason);

@override
String toString() {
  return 'SessionArchivedRejection(sessionId: $sessionId, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $SessionArchivedRejectionCopyWith<$Res>  {
  factory $SessionArchivedRejectionCopyWith(SessionArchivedRejection value, $Res Function(SessionArchivedRejection) _then) = _$SessionArchivedRejectionCopyWithImpl;
@useResult
$Res call({
 String sessionId, SessionArchivedReason reason
});




}
/// @nodoc
class _$SessionArchivedRejectionCopyWithImpl<$Res>
    implements $SessionArchivedRejectionCopyWith<$Res> {
  _$SessionArchivedRejectionCopyWithImpl(this._self, this._then);

  final SessionArchivedRejection _self;
  final $Res Function(SessionArchivedRejection) _then;

/// Create a copy of SessionArchivedRejection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? reason = null,}) {
  return _then(_self.copyWith(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as SessionArchivedReason,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SessionArchivedRejection implements SessionArchivedRejection {
  const _SessionArchivedRejection({required this.sessionId, required this.reason});
  factory _SessionArchivedRejection.fromJson(Map<String, dynamic> json) => _$SessionArchivedRejectionFromJson(json);

@override final  String sessionId;
@override final  SessionArchivedReason reason;

/// Create a copy of SessionArchivedRejection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionArchivedRejectionCopyWith<_SessionArchivedRejection> get copyWith => __$SessionArchivedRejectionCopyWithImpl<_SessionArchivedRejection>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionArchivedRejectionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionArchivedRejection&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.reason, reason) || other.reason == reason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,reason);

@override
String toString() {
  return 'SessionArchivedRejection(sessionId: $sessionId, reason: $reason)';
}


}

/// @nodoc
abstract mixin class _$SessionArchivedRejectionCopyWith<$Res> implements $SessionArchivedRejectionCopyWith<$Res> {
  factory _$SessionArchivedRejectionCopyWith(_SessionArchivedRejection value, $Res Function(_SessionArchivedRejection) _then) = __$SessionArchivedRejectionCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, SessionArchivedReason reason
});




}
/// @nodoc
class __$SessionArchivedRejectionCopyWithImpl<$Res>
    implements _$SessionArchivedRejectionCopyWith<$Res> {
  __$SessionArchivedRejectionCopyWithImpl(this._self, this._then);

  final _SessionArchivedRejection _self;
  final $Res Function(_SessionArchivedRejection) _then;

/// Create a copy of SessionArchivedRejection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? reason = null,}) {
  return _then(_SessionArchivedRejection(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as SessionArchivedReason,
  ));
}


}

// dart format on
