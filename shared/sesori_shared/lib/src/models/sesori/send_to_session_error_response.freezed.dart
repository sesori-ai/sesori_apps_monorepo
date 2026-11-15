// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'send_to_session_error_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SendToSessionErrorResponse {

@JsonKey(unknownEnumValue: SendToSessionErrorCode.unknown) SendToSessionErrorCode get code;/// The harness's own explanation, written for the user and safe to show,
/// when it refused the target prompt for a reason it explained. Null for
/// every other failure.
 String? get message;
/// Create a copy of SendToSessionErrorResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SendToSessionErrorResponseCopyWith<SendToSessionErrorResponse> get copyWith => _$SendToSessionErrorResponseCopyWithImpl<SendToSessionErrorResponse>(this as SendToSessionErrorResponse, _$identity);

  /// Serializes this SendToSessionErrorResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SendToSessionErrorResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SendToSessionErrorResponse&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.message, _this.message) || other.message == _this.message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SendToSessionErrorResponse;
  return Object.hash(runtimeType,_this.code,_this.message);
}

@override
String toString() {
  final _this = this as SendToSessionErrorResponse;
  return 'SendToSessionErrorResponse(code: ${_this.code}, message: ${_this.message})';
}


}

/// @nodoc
abstract mixin class $SendToSessionErrorResponseCopyWith<$Res>  {
  factory $SendToSessionErrorResponseCopyWith(SendToSessionErrorResponse value, $Res Function(SendToSessionErrorResponse) _then) = _$SendToSessionErrorResponseCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: SendToSessionErrorCode.unknown) SendToSessionErrorCode code, String? message
});




}
/// @nodoc
class _$SendToSessionErrorResponseCopyWithImpl<$Res>
    implements $SendToSessionErrorResponseCopyWith<$Res> {
  _$SendToSessionErrorResponseCopyWithImpl(this._self, this._then);

  final SendToSessionErrorResponse _self;
  final $Res Function(SendToSessionErrorResponse) _then;

/// Create a copy of SendToSessionErrorResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? message = freezed,}) {
  return _then(SendToSessionErrorResponse(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as SendToSessionErrorCode,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SendToSessionErrorResponse implements SendToSessionErrorResponse {
  const _SendToSessionErrorResponse({@JsonKey(unknownEnumValue: SendToSessionErrorCode.unknown) required this.code, required this.message});
  factory _SendToSessionErrorResponse.fromJson(Map<String, dynamic> json) => _$SendToSessionErrorResponseFromJson(json);

@override@JsonKey(unknownEnumValue: SendToSessionErrorCode.unknown) final  SendToSessionErrorCode code;
/// The harness's own explanation, written for the user and safe to show,
/// when it refused the target prompt for a reason it explained. Null for
/// every other failure.
@override final  String? message;

/// Create a copy of SendToSessionErrorResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SendToSessionErrorResponseCopyWith<_SendToSessionErrorResponse> get copyWith => __$SendToSessionErrorResponseCopyWithImpl<_SendToSessionErrorResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SendToSessionErrorResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SendToSessionErrorResponse&&(identical(other.code, code) || other.code == code)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,code,message);
}

@override
String toString() {
    return 'SendToSessionErrorResponse(code: $code, message: $message)';
}


}

/// @nodoc
abstract mixin class _$SendToSessionErrorResponseCopyWith<$Res> implements $SendToSessionErrorResponseCopyWith<$Res> {
  factory _$SendToSessionErrorResponseCopyWith(_SendToSessionErrorResponse value, $Res Function(_SendToSessionErrorResponse) _then) = __$SendToSessionErrorResponseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: SendToSessionErrorCode.unknown) SendToSessionErrorCode code, String? message
});




}
/// @nodoc
class __$SendToSessionErrorResponseCopyWithImpl<$Res>
    implements _$SendToSessionErrorResponseCopyWith<$Res> {
  __$SendToSessionErrorResponseCopyWithImpl(this._self, this._then);

  final _SendToSessionErrorResponse _self;
  final $Res Function(_SendToSessionErrorResponse) _then;

/// Create a copy of SendToSessionErrorResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? message = freezed,}) {
  return _then(_SendToSessionErrorResponse(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as SendToSessionErrorCode,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
