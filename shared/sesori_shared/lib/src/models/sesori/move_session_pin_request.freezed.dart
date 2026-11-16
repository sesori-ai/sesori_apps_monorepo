// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'move_session_pin_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MoveSessionPinRequest {

 String get sessionId; String? get afterSessionId;
/// Create a copy of MoveSessionPinRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MoveSessionPinRequestCopyWith<MoveSessionPinRequest> get copyWith => _$MoveSessionPinRequestCopyWithImpl<MoveSessionPinRequest>(this as MoveSessionPinRequest, _$identity);

  /// Serializes this MoveSessionPinRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MoveSessionPinRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MoveSessionPinRequest&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.afterSessionId, _this.afterSessionId) || other.afterSessionId == _this.afterSessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MoveSessionPinRequest;
  return Object.hash(runtimeType,_this.sessionId,_this.afterSessionId);
}

@override
String toString() {
  final _this = this as MoveSessionPinRequest;
  return 'MoveSessionPinRequest(sessionId: ${_this.sessionId}, afterSessionId: ${_this.afterSessionId})';
}


}

/// @nodoc
abstract mixin class $MoveSessionPinRequestCopyWith<$Res>  {
  factory $MoveSessionPinRequestCopyWith(MoveSessionPinRequest value, $Res Function(MoveSessionPinRequest) _then) = _$MoveSessionPinRequestCopyWithImpl;
@useResult
$Res call({
 String sessionId, String? afterSessionId
});




}
/// @nodoc
class _$MoveSessionPinRequestCopyWithImpl<$Res>
    implements $MoveSessionPinRequestCopyWith<$Res> {
  _$MoveSessionPinRequestCopyWithImpl(this._self, this._then);

  final MoveSessionPinRequest _self;
  final $Res Function(MoveSessionPinRequest) _then;

/// Create a copy of MoveSessionPinRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? afterSessionId = freezed,}) {
  return _then(MoveSessionPinRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,afterSessionId: freezed == afterSessionId ? _self.afterSessionId : afterSessionId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _MoveSessionPinRequest implements MoveSessionPinRequest {
  const _MoveSessionPinRequest({required this.sessionId, required this.afterSessionId});
  factory _MoveSessionPinRequest.fromJson(Map<String, dynamic> json) => _$MoveSessionPinRequestFromJson(json);

@override final  String sessionId;
@override final  String? afterSessionId;

/// Create a copy of MoveSessionPinRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MoveSessionPinRequestCopyWith<_MoveSessionPinRequest> get copyWith => __$MoveSessionPinRequestCopyWithImpl<_MoveSessionPinRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MoveSessionPinRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MoveSessionPinRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.afterSessionId, afterSessionId) || other.afterSessionId == afterSessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,afterSessionId);
}

@override
String toString() {
    return 'MoveSessionPinRequest(sessionId: $sessionId, afterSessionId: $afterSessionId)';
}


}

/// @nodoc
abstract mixin class _$MoveSessionPinRequestCopyWith<$Res> implements $MoveSessionPinRequestCopyWith<$Res> {
  factory _$MoveSessionPinRequestCopyWith(_MoveSessionPinRequest value, $Res Function(_MoveSessionPinRequest) _then) = __$MoveSessionPinRequestCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, String? afterSessionId
});




}
/// @nodoc
class __$MoveSessionPinRequestCopyWithImpl<$Res>
    implements _$MoveSessionPinRequestCopyWith<$Res> {
  __$MoveSessionPinRequestCopyWithImpl(this._self, this._then);

  final _MoveSessionPinRequest _self;
  final $Res Function(_MoveSessionPinRequest) _then;

/// Create a copy of MoveSessionPinRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? afterSessionId = freezed,}) {
  return _then(_MoveSessionPinRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,afterSessionId: freezed == afterSessionId ? _self.afterSessionId : afterSessionId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$MoveSessionPinResponse {

 List<Session> get sessions;
/// Create a copy of MoveSessionPinResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MoveSessionPinResponseCopyWith<MoveSessionPinResponse> get copyWith => _$MoveSessionPinResponseCopyWithImpl<MoveSessionPinResponse>(this as MoveSessionPinResponse, _$identity);

  /// Serializes this MoveSessionPinResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MoveSessionPinResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MoveSessionPinResponse&&const DeepCollectionEquality().equals(other.sessions, _this.sessions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MoveSessionPinResponse;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.sessions));
}

@override
String toString() {
  final _this = this as MoveSessionPinResponse;
  return 'MoveSessionPinResponse(sessions: ${_this.sessions})';
}


}

/// @nodoc
abstract mixin class $MoveSessionPinResponseCopyWith<$Res>  {
  factory $MoveSessionPinResponseCopyWith(MoveSessionPinResponse value, $Res Function(MoveSessionPinResponse) _then) = _$MoveSessionPinResponseCopyWithImpl;
@useResult
$Res call({
 List<Session> sessions
});




}
/// @nodoc
class _$MoveSessionPinResponseCopyWithImpl<$Res>
    implements $MoveSessionPinResponseCopyWith<$Res> {
  _$MoveSessionPinResponseCopyWithImpl(this._self, this._then);

  final MoveSessionPinResponse _self;
  final $Res Function(MoveSessionPinResponse) _then;

/// Create a copy of MoveSessionPinResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessions = null,}) {
  return _then(MoveSessionPinResponse(
sessions: null == sessions ? _self.sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<Session>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _MoveSessionPinResponse implements MoveSessionPinResponse {
  const _MoveSessionPinResponse({required  List<Session> sessions}): _sessions = sessions;
  factory _MoveSessionPinResponse.fromJson(Map<String, dynamic> json) => _$MoveSessionPinResponseFromJson(json);

 final  List<Session> _sessions;
@override List<Session> get sessions {
  if (_sessions is EqualUnmodifiableListView) return _sessions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sessions);
}


/// Create a copy of MoveSessionPinResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MoveSessionPinResponseCopyWith<_MoveSessionPinResponse> get copyWith => __$MoveSessionPinResponseCopyWithImpl<_MoveSessionPinResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MoveSessionPinResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MoveSessionPinResponse&&const DeepCollectionEquality().equals(other.sessions, _sessions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_sessions));
}

@override
String toString() {
    return 'MoveSessionPinResponse(sessions: $sessions)';
}


}

/// @nodoc
abstract mixin class _$MoveSessionPinResponseCopyWith<$Res> implements $MoveSessionPinResponseCopyWith<$Res> {
  factory _$MoveSessionPinResponseCopyWith(_MoveSessionPinResponse value, $Res Function(_MoveSessionPinResponse) _then) = __$MoveSessionPinResponseCopyWithImpl;
@override @useResult
$Res call({
 List<Session> sessions
});




}
/// @nodoc
class __$MoveSessionPinResponseCopyWithImpl<$Res>
    implements _$MoveSessionPinResponseCopyWith<$Res> {
  __$MoveSessionPinResponseCopyWithImpl(this._self, this._then);

  final _MoveSessionPinResponse _self;
  final $Res Function(_MoveSessionPinResponse) _then;

/// Create a copy of MoveSessionPinResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessions = null,}) {
  return _then(_MoveSessionPinResponse(
sessions: null == sessions ? _self._sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<Session>,
  ));
}


}

// dart format on
