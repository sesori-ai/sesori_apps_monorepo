// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'set_session_auto_continuation_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SetSessionAutoContinuationRequest {

 String get sessionId; bool get enabled;
/// Create a copy of SetSessionAutoContinuationRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SetSessionAutoContinuationRequestCopyWith<SetSessionAutoContinuationRequest> get copyWith => _$SetSessionAutoContinuationRequestCopyWithImpl<SetSessionAutoContinuationRequest>(this as SetSessionAutoContinuationRequest, _$identity);

  /// Serializes this SetSessionAutoContinuationRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SetSessionAutoContinuationRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SetSessionAutoContinuationRequest&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SetSessionAutoContinuationRequest;
  return Object.hash(runtimeType,_this.sessionId,_this.enabled);
}

@override
String toString() {
  final _this = this as SetSessionAutoContinuationRequest;
  return 'SetSessionAutoContinuationRequest(sessionId: ${_this.sessionId}, enabled: ${_this.enabled})';
}


}

/// @nodoc
abstract mixin class $SetSessionAutoContinuationRequestCopyWith<$Res>  {
  factory $SetSessionAutoContinuationRequestCopyWith(SetSessionAutoContinuationRequest value, $Res Function(SetSessionAutoContinuationRequest) _then) = _$SetSessionAutoContinuationRequestCopyWithImpl;
@useResult
$Res call({
 String sessionId, bool enabled
});




}
/// @nodoc
class _$SetSessionAutoContinuationRequestCopyWithImpl<$Res>
    implements $SetSessionAutoContinuationRequestCopyWith<$Res> {
  _$SetSessionAutoContinuationRequestCopyWithImpl(this._self, this._then);

  final SetSessionAutoContinuationRequest _self;
  final $Res Function(SetSessionAutoContinuationRequest) _then;

/// Create a copy of SetSessionAutoContinuationRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? enabled = null,}) {
  return _then(SetSessionAutoContinuationRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SetSessionAutoContinuationRequest implements SetSessionAutoContinuationRequest {
  const _SetSessionAutoContinuationRequest({required this.sessionId, required this.enabled});
  factory _SetSessionAutoContinuationRequest.fromJson(Map<String, dynamic> json) => _$SetSessionAutoContinuationRequestFromJson(json);

@override final  String sessionId;
@override final  bool enabled;

/// Create a copy of SetSessionAutoContinuationRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SetSessionAutoContinuationRequestCopyWith<_SetSessionAutoContinuationRequest> get copyWith => __$SetSessionAutoContinuationRequestCopyWithImpl<_SetSessionAutoContinuationRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SetSessionAutoContinuationRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SetSessionAutoContinuationRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.enabled, enabled) || other.enabled == enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,enabled);
}

@override
String toString() {
    return 'SetSessionAutoContinuationRequest(sessionId: $sessionId, enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class _$SetSessionAutoContinuationRequestCopyWith<$Res> implements $SetSessionAutoContinuationRequestCopyWith<$Res> {
  factory _$SetSessionAutoContinuationRequestCopyWith(_SetSessionAutoContinuationRequest value, $Res Function(_SetSessionAutoContinuationRequest) _then) = __$SetSessionAutoContinuationRequestCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, bool enabled
});




}
/// @nodoc
class __$SetSessionAutoContinuationRequestCopyWithImpl<$Res>
    implements _$SetSessionAutoContinuationRequestCopyWith<$Res> {
  __$SetSessionAutoContinuationRequestCopyWithImpl(this._self, this._then);

  final _SetSessionAutoContinuationRequest _self;
  final $Res Function(_SetSessionAutoContinuationRequest) _then;

/// Create a copy of SetSessionAutoContinuationRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? enabled = null,}) {
  return _then(_SetSessionAutoContinuationRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
