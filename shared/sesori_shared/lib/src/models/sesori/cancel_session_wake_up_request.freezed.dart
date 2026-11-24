// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cancel_session_wake_up_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CancelSessionWakeUpRequest {

/// The root session the wake-up belongs to.
 String get sessionId; String get wakeUpId;
/// Create a copy of CancelSessionWakeUpRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CancelSessionWakeUpRequestCopyWith<CancelSessionWakeUpRequest> get copyWith => _$CancelSessionWakeUpRequestCopyWithImpl<CancelSessionWakeUpRequest>(this as CancelSessionWakeUpRequest, _$identity);

  /// Serializes this CancelSessionWakeUpRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CancelSessionWakeUpRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CancelSessionWakeUpRequest&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.wakeUpId, _this.wakeUpId) || other.wakeUpId == _this.wakeUpId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CancelSessionWakeUpRequest;
  return Object.hash(runtimeType,_this.sessionId,_this.wakeUpId);
}

@override
String toString() {
  final _this = this as CancelSessionWakeUpRequest;
  return 'CancelSessionWakeUpRequest(sessionId: ${_this.sessionId}, wakeUpId: ${_this.wakeUpId})';
}


}

/// @nodoc
abstract mixin class $CancelSessionWakeUpRequestCopyWith<$Res>  {
  factory $CancelSessionWakeUpRequestCopyWith(CancelSessionWakeUpRequest value, $Res Function(CancelSessionWakeUpRequest) _then) = _$CancelSessionWakeUpRequestCopyWithImpl;
@useResult
$Res call({
 String sessionId, String wakeUpId
});




}
/// @nodoc
class _$CancelSessionWakeUpRequestCopyWithImpl<$Res>
    implements $CancelSessionWakeUpRequestCopyWith<$Res> {
  _$CancelSessionWakeUpRequestCopyWithImpl(this._self, this._then);

  final CancelSessionWakeUpRequest _self;
  final $Res Function(CancelSessionWakeUpRequest) _then;

/// Create a copy of CancelSessionWakeUpRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? wakeUpId = null,}) {
  return _then(CancelSessionWakeUpRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,wakeUpId: null == wakeUpId ? _self.wakeUpId : wakeUpId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CancelSessionWakeUpRequest implements CancelSessionWakeUpRequest {
  const _CancelSessionWakeUpRequest({required this.sessionId, required this.wakeUpId});
  factory _CancelSessionWakeUpRequest.fromJson(Map<String, dynamic> json) => _$CancelSessionWakeUpRequestFromJson(json);

/// The root session the wake-up belongs to.
@override final  String sessionId;
@override final  String wakeUpId;

/// Create a copy of CancelSessionWakeUpRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CancelSessionWakeUpRequestCopyWith<_CancelSessionWakeUpRequest> get copyWith => __$CancelSessionWakeUpRequestCopyWithImpl<_CancelSessionWakeUpRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CancelSessionWakeUpRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CancelSessionWakeUpRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.wakeUpId, wakeUpId) || other.wakeUpId == wakeUpId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,wakeUpId);
}

@override
String toString() {
    return 'CancelSessionWakeUpRequest(sessionId: $sessionId, wakeUpId: $wakeUpId)';
}


}

/// @nodoc
abstract mixin class _$CancelSessionWakeUpRequestCopyWith<$Res> implements $CancelSessionWakeUpRequestCopyWith<$Res> {
  factory _$CancelSessionWakeUpRequestCopyWith(_CancelSessionWakeUpRequest value, $Res Function(_CancelSessionWakeUpRequest) _then) = __$CancelSessionWakeUpRequestCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, String wakeUpId
});




}
/// @nodoc
class __$CancelSessionWakeUpRequestCopyWithImpl<$Res>
    implements _$CancelSessionWakeUpRequestCopyWith<$Res> {
  __$CancelSessionWakeUpRequestCopyWithImpl(this._self, this._then);

  final _CancelSessionWakeUpRequest _self;
  final $Res Function(_CancelSessionWakeUpRequest) _then;

/// Create a copy of CancelSessionWakeUpRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? wakeUpId = null,}) {
  return _then(_CancelSessionWakeUpRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,wakeUpId: null == wakeUpId ? _self.wakeUpId : wakeUpId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
