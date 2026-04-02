// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'send_command_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SendCommandRequest {

 String get sessionId; String get command; String get arguments;
/// Create a copy of SendCommandRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SendCommandRequestCopyWith<SendCommandRequest> get copyWith => _$SendCommandRequestCopyWithImpl<SendCommandRequest>(this as SendCommandRequest, _$identity);

  /// Serializes this SendCommandRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SendCommandRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.command, command) || other.command == command)&&(identical(other.arguments, arguments) || other.arguments == arguments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,command,arguments);

@override
String toString() {
  return 'SendCommandRequest(sessionId: $sessionId, command: $command, arguments: $arguments)';
}


}

/// @nodoc
abstract mixin class $SendCommandRequestCopyWith<$Res>  {
  factory $SendCommandRequestCopyWith(SendCommandRequest value, $Res Function(SendCommandRequest) _then) = _$SendCommandRequestCopyWithImpl;
@useResult
$Res call({
 String sessionId, String command, String arguments
});




}
/// @nodoc
class _$SendCommandRequestCopyWithImpl<$Res>
    implements $SendCommandRequestCopyWith<$Res> {
  _$SendCommandRequestCopyWithImpl(this._self, this._then);

  final SendCommandRequest _self;
  final $Res Function(SendCommandRequest) _then;

/// Create a copy of SendCommandRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = null,Object? command = null,Object? arguments = null,}) {
  return _then(_self.copyWith(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,command: null == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String,arguments: null == arguments ? _self.arguments : arguments // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SendCommandRequest implements SendCommandRequest {
  const _SendCommandRequest({required this.sessionId, required this.command, required this.arguments});
  factory _SendCommandRequest.fromJson(Map<String, dynamic> json) => _$SendCommandRequestFromJson(json);

@override final  String sessionId;
@override final  String command;
@override final  String arguments;

/// Create a copy of SendCommandRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SendCommandRequestCopyWith<_SendCommandRequest> get copyWith => __$SendCommandRequestCopyWithImpl<_SendCommandRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SendCommandRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SendCommandRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.command, command) || other.command == command)&&(identical(other.arguments, arguments) || other.arguments == arguments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,command,arguments);

@override
String toString() {
  return 'SendCommandRequest(sessionId: $sessionId, command: $command, arguments: $arguments)';
}


}

/// @nodoc
abstract mixin class _$SendCommandRequestCopyWith<$Res> implements $SendCommandRequestCopyWith<$Res> {
  factory _$SendCommandRequestCopyWith(_SendCommandRequest value, $Res Function(_SendCommandRequest) _then) = __$SendCommandRequestCopyWithImpl;
@override @useResult
$Res call({
 String sessionId, String command, String arguments
});




}
/// @nodoc
class __$SendCommandRequestCopyWithImpl<$Res>
    implements _$SendCommandRequestCopyWith<$Res> {
  __$SendCommandRequestCopyWithImpl(this._self, this._then);

  final _SendCommandRequest _self;
  final $Res Function(_SendCommandRequest) _then;

/// Create a copy of SendCommandRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? command = null,Object? arguments = null,}) {
  return _then(_SendCommandRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,command: null == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as String,arguments: null == arguments ? _self.arguments : arguments // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
