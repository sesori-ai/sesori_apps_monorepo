// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reply_to_permission_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReplyToPermissionRequest {

 String get requestId; String get sessionId; PermissionReply get reply;
/// Create a copy of ReplyToPermissionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReplyToPermissionRequestCopyWith<ReplyToPermissionRequest> get copyWith => _$ReplyToPermissionRequestCopyWithImpl<ReplyToPermissionRequest>(this as ReplyToPermissionRequest, _$identity);

  /// Serializes this ReplyToPermissionRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReplyToPermissionRequest&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.reply, reply) || other.reply == reply));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,requestId,sessionId,reply);

@override
String toString() {
  return 'ReplyToPermissionRequest(requestId: $requestId, sessionId: $sessionId, reply: $reply)';
}


}

/// @nodoc
abstract mixin class $ReplyToPermissionRequestCopyWith<$Res>  {
  factory $ReplyToPermissionRequestCopyWith(ReplyToPermissionRequest value, $Res Function(ReplyToPermissionRequest) _then) = _$ReplyToPermissionRequestCopyWithImpl;
@useResult
$Res call({
 String requestId, String sessionId, PermissionReply reply
});




}
/// @nodoc
class _$ReplyToPermissionRequestCopyWithImpl<$Res>
    implements $ReplyToPermissionRequestCopyWith<$Res> {
  _$ReplyToPermissionRequestCopyWithImpl(this._self, this._then);

  final ReplyToPermissionRequest _self;
  final $Res Function(ReplyToPermissionRequest) _then;

/// Create a copy of ReplyToPermissionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? requestId = null,Object? sessionId = null,Object? reply = null,}) {
  return _then(_self.copyWith(
requestId: null == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,reply: null == reply ? _self.reply : reply // ignore: cast_nullable_to_non_nullable
as PermissionReply,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _ReplyToPermissionRequest implements ReplyToPermissionRequest {
  const _ReplyToPermissionRequest({required this.requestId, required this.sessionId, required this.reply});
  factory _ReplyToPermissionRequest.fromJson(Map<String, dynamic> json) => _$ReplyToPermissionRequestFromJson(json);

@override final  String requestId;
@override final  String sessionId;
@override final  PermissionReply reply;

/// Create a copy of ReplyToPermissionRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReplyToPermissionRequestCopyWith<_ReplyToPermissionRequest> get copyWith => __$ReplyToPermissionRequestCopyWithImpl<_ReplyToPermissionRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReplyToPermissionRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReplyToPermissionRequest&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.reply, reply) || other.reply == reply));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,requestId,sessionId,reply);

@override
String toString() {
  return 'ReplyToPermissionRequest(requestId: $requestId, sessionId: $sessionId, reply: $reply)';
}


}

/// @nodoc
abstract mixin class _$ReplyToPermissionRequestCopyWith<$Res> implements $ReplyToPermissionRequestCopyWith<$Res> {
  factory _$ReplyToPermissionRequestCopyWith(_ReplyToPermissionRequest value, $Res Function(_ReplyToPermissionRequest) _then) = __$ReplyToPermissionRequestCopyWithImpl;
@override @useResult
$Res call({
 String requestId, String sessionId, PermissionReply reply
});




}
/// @nodoc
class __$ReplyToPermissionRequestCopyWithImpl<$Res>
    implements _$ReplyToPermissionRequestCopyWith<$Res> {
  __$ReplyToPermissionRequestCopyWithImpl(this._self, this._then);

  final _ReplyToPermissionRequest _self;
  final $Res Function(_ReplyToPermissionRequest) _then;

/// Create a copy of ReplyToPermissionRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? requestId = null,Object? sessionId = null,Object? reply = null,}) {
  return _then(_ReplyToPermissionRequest(
requestId: null == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,reply: null == reply ? _self.reply : reply // ignore: cast_nullable_to_non_nullable
as PermissionReply,
  ));
}


}

// dart format on
