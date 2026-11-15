// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'send_to_session_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SendToSessionRequest {

 String get sourceSessionId; String get targetSessionId;
/// Create a copy of SendToSessionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SendToSessionRequestCopyWith<SendToSessionRequest> get copyWith => _$SendToSessionRequestCopyWithImpl<SendToSessionRequest>(this as SendToSessionRequest, _$identity);

  /// Serializes this SendToSessionRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SendToSessionRequest;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SendToSessionRequest&&(identical(other.sourceSessionId, _this.sourceSessionId) || other.sourceSessionId == _this.sourceSessionId)&&(identical(other.targetSessionId, _this.targetSessionId) || other.targetSessionId == _this.targetSessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SendToSessionRequest;
  return Object.hash(runtimeType,_this.sourceSessionId,_this.targetSessionId);
}

@override
String toString() {
  final _this = this as SendToSessionRequest;
  return 'SendToSessionRequest(sourceSessionId: ${_this.sourceSessionId}, targetSessionId: ${_this.targetSessionId})';
}


}

/// @nodoc
abstract mixin class $SendToSessionRequestCopyWith<$Res>  {
  factory $SendToSessionRequestCopyWith(SendToSessionRequest value, $Res Function(SendToSessionRequest) _then) = _$SendToSessionRequestCopyWithImpl;
@useResult
$Res call({
 String sourceSessionId, String targetSessionId
});




}
/// @nodoc
class _$SendToSessionRequestCopyWithImpl<$Res>
    implements $SendToSessionRequestCopyWith<$Res> {
  _$SendToSessionRequestCopyWithImpl(this._self, this._then);

  final SendToSessionRequest _self;
  final $Res Function(SendToSessionRequest) _then;

/// Create a copy of SendToSessionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sourceSessionId = null,Object? targetSessionId = null,}) {
  return _then(SendToSessionRequest(
sourceSessionId: null == sourceSessionId ? _self.sourceSessionId : sourceSessionId // ignore: cast_nullable_to_non_nullable
as String,targetSessionId: null == targetSessionId ? _self.targetSessionId : targetSessionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SendToSessionRequest implements SendToSessionRequest {
  const _SendToSessionRequest({required this.sourceSessionId, required this.targetSessionId});
  factory _SendToSessionRequest.fromJson(Map<String, dynamic> json) => _$SendToSessionRequestFromJson(json);

@override final  String sourceSessionId;
@override final  String targetSessionId;

/// Create a copy of SendToSessionRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SendToSessionRequestCopyWith<_SendToSessionRequest> get copyWith => __$SendToSessionRequestCopyWithImpl<_SendToSessionRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SendToSessionRequestToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SendToSessionRequest&&(identical(other.sourceSessionId, sourceSessionId) || other.sourceSessionId == sourceSessionId)&&(identical(other.targetSessionId, targetSessionId) || other.targetSessionId == targetSessionId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,sourceSessionId,targetSessionId);
}

@override
String toString() {
    return 'SendToSessionRequest(sourceSessionId: $sourceSessionId, targetSessionId: $targetSessionId)';
}


}

/// @nodoc
abstract mixin class _$SendToSessionRequestCopyWith<$Res> implements $SendToSessionRequestCopyWith<$Res> {
  factory _$SendToSessionRequestCopyWith(_SendToSessionRequest value, $Res Function(_SendToSessionRequest) _then) = __$SendToSessionRequestCopyWithImpl;
@override @useResult
$Res call({
 String sourceSessionId, String targetSessionId
});




}
/// @nodoc
class __$SendToSessionRequestCopyWithImpl<$Res>
    implements _$SendToSessionRequestCopyWith<$Res> {
  __$SendToSessionRequestCopyWithImpl(this._self, this._then);

  final _SendToSessionRequest _self;
  final $Res Function(_SendToSessionRequest) _then;

/// Create a copy of SendToSessionRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sourceSessionId = null,Object? targetSessionId = null,}) {
  return _then(_SendToSessionRequest(
sourceSessionId: null == sourceSessionId ? _self.sourceSessionId : sourceSessionId // ignore: cast_nullable_to_non_nullable
as String,targetSessionId: null == targetSessionId ? _self.targetSessionId : targetSessionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
