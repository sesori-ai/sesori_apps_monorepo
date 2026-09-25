// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_approval_override.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SetSessionApprovalOverrideRequest {

 String get sessionId; SessionApprovalMode? get approvalOverride;
/// Create a copy of SetSessionApprovalOverrideRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SetSessionApprovalOverrideRequestCopyWith<SetSessionApprovalOverrideRequest> get copyWith => _$SetSessionApprovalOverrideRequestCopyWithImpl<SetSessionApprovalOverrideRequest>(this as SetSessionApprovalOverrideRequest, _$identity);

  /// Serializes this SetSessionApprovalOverrideRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SetSessionApprovalOverrideRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SetSessionApprovalOverrideRequest&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.approvalOverride, _this.approvalOverride) || other.approvalOverride == _this.approvalOverride));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SetSessionApprovalOverrideRequest;
  return Object.hash(runtimeType,_this.sessionId,_this.approvalOverride);
}

@override
String toString() {
  final _this = this as SetSessionApprovalOverrideRequest;
  return 'SetSessionApprovalOverrideRequest(sessionId: ${_this.sessionId}, approvalOverride: ${_this.approvalOverride})';
}


}

/// @nodoc
abstract mixin class $SetSessionApprovalOverrideRequestCopyWith<$Res>  {
  factory $SetSessionApprovalOverrideRequestCopyWith(SetSessionApprovalOverrideRequest value, $Res Function(SetSessionApprovalOverrideRequest) _then) = _$SetSessionApprovalOverrideRequestCopyWithImpl;
@useResult
$Res call({
 String sessionId, SessionApprovalMode? approvalOverride
});




}
/// @nodoc
class _$SetSessionApprovalOverrideRequestCopyWithImpl<$Res>
    implements $SetSessionApprovalOverrideRequestCopyWith<$Res> {
  _$SetSessionApprovalOverrideRequestCopyWithImpl(this._self, this._then);

  final SetSessionApprovalOverrideRequest _self;
  final $Res Function(SetSessionApprovalOverrideRequest) _then;

/// Create a copy of SetSessionApprovalOverrideRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? approvalOverride = freezed,}) {
  return _then(SetSessionApprovalOverrideRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,approvalOverride: freezed == approvalOverride ? _self.approvalOverride : approvalOverride // ignore: cast_nullable_to_non_nullable
as SessionApprovalMode?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SetSessionApprovalOverrideRequest implements SetSessionApprovalOverrideRequest {
  const _SetSessionApprovalOverrideRequest({required this.sessionId, required this.approvalOverride});
  factory _SetSessionApprovalOverrideRequest.fromJson(Map<String, dynamic> json) => _$SetSessionApprovalOverrideRequestFromJson(json);

@override final  String sessionId;
@override final  SessionApprovalMode? approvalOverride;

/// Create a copy of SetSessionApprovalOverrideRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SetSessionApprovalOverrideRequestCopyWith<_SetSessionApprovalOverrideRequest> get copyWith => __$SetSessionApprovalOverrideRequestCopyWithImpl<_SetSessionApprovalOverrideRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SetSessionApprovalOverrideRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SetSessionApprovalOverrideRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.approvalOverride, approvalOverride) || other.approvalOverride == approvalOverride));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,approvalOverride);
}

@override
String toString() {
    return 'SetSessionApprovalOverrideRequest(sessionId: $sessionId, approvalOverride: $approvalOverride)';
}


}

/// @nodoc
abstract mixin class _$SetSessionApprovalOverrideRequestCopyWith<$Res> implements $SetSessionApprovalOverrideRequestCopyWith<$Res> {
  factory _$SetSessionApprovalOverrideRequestCopyWith(_SetSessionApprovalOverrideRequest value, $Res Function(_SetSessionApprovalOverrideRequest) _then) = __$SetSessionApprovalOverrideRequestCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, SessionApprovalMode? approvalOverride
});




}
/// @nodoc
class __$SetSessionApprovalOverrideRequestCopyWithImpl<$Res>
    implements _$SetSessionApprovalOverrideRequestCopyWith<$Res> {
  __$SetSessionApprovalOverrideRequestCopyWithImpl(this._self, this._then);

  final _SetSessionApprovalOverrideRequest _self;
  final $Res Function(_SetSessionApprovalOverrideRequest) _then;

/// Create a copy of SetSessionApprovalOverrideRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? approvalOverride = freezed,}) {
  return _then(_SetSessionApprovalOverrideRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,approvalOverride: freezed == approvalOverride ? _self.approvalOverride : approvalOverride // ignore: cast_nullable_to_non_nullable
as SessionApprovalMode?,
  ));
}


}


/// @nodoc
mixin _$SessionApprovalOverrideErrorResponse {

@JsonKey(unknownEnumValue: SessionApprovalOverrideErrorCode.unknown) SessionApprovalOverrideErrorCode get code;
/// Create a copy of SessionApprovalOverrideErrorResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionApprovalOverrideErrorResponseCopyWith<SessionApprovalOverrideErrorResponse> get copyWith => _$SessionApprovalOverrideErrorResponseCopyWithImpl<SessionApprovalOverrideErrorResponse>(this as SessionApprovalOverrideErrorResponse, _$identity);

  /// Serializes this SessionApprovalOverrideErrorResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SessionApprovalOverrideErrorResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionApprovalOverrideErrorResponse&&(identical(other.code, _this.code) || other.code == _this.code));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SessionApprovalOverrideErrorResponse;
  return Object.hash(runtimeType,_this.code);
}

@override
String toString() {
  final _this = this as SessionApprovalOverrideErrorResponse;
  return 'SessionApprovalOverrideErrorResponse(code: ${_this.code})';
}


}

/// @nodoc
abstract mixin class $SessionApprovalOverrideErrorResponseCopyWith<$Res>  {
  factory $SessionApprovalOverrideErrorResponseCopyWith(SessionApprovalOverrideErrorResponse value, $Res Function(SessionApprovalOverrideErrorResponse) _then) = _$SessionApprovalOverrideErrorResponseCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: SessionApprovalOverrideErrorCode.unknown) SessionApprovalOverrideErrorCode code
});




}
/// @nodoc
class _$SessionApprovalOverrideErrorResponseCopyWithImpl<$Res>
    implements $SessionApprovalOverrideErrorResponseCopyWith<$Res> {
  _$SessionApprovalOverrideErrorResponseCopyWithImpl(this._self, this._then);

  final SessionApprovalOverrideErrorResponse _self;
  final $Res Function(SessionApprovalOverrideErrorResponse) _then;

/// Create a copy of SessionApprovalOverrideErrorResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,}) {
  return _then(SessionApprovalOverrideErrorResponse(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as SessionApprovalOverrideErrorCode,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SessionApprovalOverrideErrorResponse implements SessionApprovalOverrideErrorResponse {
  const _SessionApprovalOverrideErrorResponse({@JsonKey(unknownEnumValue: SessionApprovalOverrideErrorCode.unknown) required this.code});
  factory _SessionApprovalOverrideErrorResponse.fromJson(Map<String, dynamic> json) => _$SessionApprovalOverrideErrorResponseFromJson(json);

@override@JsonKey(unknownEnumValue: SessionApprovalOverrideErrorCode.unknown) final  SessionApprovalOverrideErrorCode code;

/// Create a copy of SessionApprovalOverrideErrorResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionApprovalOverrideErrorResponseCopyWith<_SessionApprovalOverrideErrorResponse> get copyWith => __$SessionApprovalOverrideErrorResponseCopyWithImpl<_SessionApprovalOverrideErrorResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionApprovalOverrideErrorResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionApprovalOverrideErrorResponse&&(identical(other.code, code) || other.code == code));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,code);
}

@override
String toString() {
    return 'SessionApprovalOverrideErrorResponse(code: $code)';
}


}

/// @nodoc
abstract mixin class _$SessionApprovalOverrideErrorResponseCopyWith<$Res> implements $SessionApprovalOverrideErrorResponseCopyWith<$Res> {
  factory _$SessionApprovalOverrideErrorResponseCopyWith(_SessionApprovalOverrideErrorResponse value, $Res Function(_SessionApprovalOverrideErrorResponse) _then) = __$SessionApprovalOverrideErrorResponseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: SessionApprovalOverrideErrorCode.unknown) SessionApprovalOverrideErrorCode code
});




}
/// @nodoc
class __$SessionApprovalOverrideErrorResponseCopyWithImpl<$Res>
    implements _$SessionApprovalOverrideErrorResponseCopyWith<$Res> {
  __$SessionApprovalOverrideErrorResponseCopyWithImpl(this._self, this._then);

  final _SessionApprovalOverrideErrorResponse _self;
  final $Res Function(_SessionApprovalOverrideErrorResponse) _then;

/// Create a copy of SessionApprovalOverrideErrorResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,}) {
  return _then(_SessionApprovalOverrideErrorResponse(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as SessionApprovalOverrideErrorCode,
  ));
}


}

// dart format on
