// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'send_prompt_error_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SendPromptErrorResponse {

@JsonKey(unknownEnumValue: SendPromptErrorCode.unknown) SendPromptErrorCode get code; String? get message;
/// Create a copy of SendPromptErrorResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SendPromptErrorResponseCopyWith<SendPromptErrorResponse> get copyWith => _$SendPromptErrorResponseCopyWithImpl<SendPromptErrorResponse>(this as SendPromptErrorResponse, _$identity);

  /// Serializes this SendPromptErrorResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SendPromptErrorResponse&&(identical(other.code, code) || other.code == code)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,message);

@override
String toString() {
  return 'SendPromptErrorResponse(code: $code, message: $message)';
}


}

/// @nodoc
abstract mixin class $SendPromptErrorResponseCopyWith<$Res>  {
  factory $SendPromptErrorResponseCopyWith(SendPromptErrorResponse value, $Res Function(SendPromptErrorResponse) _then) = _$SendPromptErrorResponseCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: SendPromptErrorCode.unknown) SendPromptErrorCode code, String? message
});




}
/// @nodoc
class _$SendPromptErrorResponseCopyWithImpl<$Res>
    implements $SendPromptErrorResponseCopyWith<$Res> {
  _$SendPromptErrorResponseCopyWithImpl(this._self, this._then);

  final SendPromptErrorResponse _self;
  final $Res Function(SendPromptErrorResponse) _then;

/// Create a copy of SendPromptErrorResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? message = freezed,}) {
  return _then(SendPromptErrorResponse(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as SendPromptErrorCode,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SendPromptErrorResponse implements SendPromptErrorResponse {
  const _SendPromptErrorResponse({@JsonKey(unknownEnumValue: SendPromptErrorCode.unknown) required this.code, required this.message});
  factory _SendPromptErrorResponse.fromJson(Map<String, dynamic> json) => _$SendPromptErrorResponseFromJson(json);

@override@JsonKey(unknownEnumValue: SendPromptErrorCode.unknown) final  SendPromptErrorCode code;
@override final  String? message;

/// Create a copy of SendPromptErrorResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SendPromptErrorResponseCopyWith<_SendPromptErrorResponse> get copyWith => __$SendPromptErrorResponseCopyWithImpl<_SendPromptErrorResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SendPromptErrorResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SendPromptErrorResponse&&(identical(other.code, code) || other.code == code)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,message);

@override
String toString() {
  return 'SendPromptErrorResponse(code: $code, message: $message)';
}


}

/// @nodoc
abstract mixin class _$SendPromptErrorResponseCopyWith<$Res> implements $SendPromptErrorResponseCopyWith<$Res> {
  factory _$SendPromptErrorResponseCopyWith(_SendPromptErrorResponse value, $Res Function(_SendPromptErrorResponse) _then) = __$SendPromptErrorResponseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: SendPromptErrorCode.unknown) SendPromptErrorCode code, String? message
});




}
/// @nodoc
class __$SendPromptErrorResponseCopyWithImpl<$Res>
    implements _$SendPromptErrorResponseCopyWith<$Res> {
  __$SendPromptErrorResponseCopyWithImpl(this._self, this._then);

  final _SendPromptErrorResponse _self;
  final $Res Function(_SendPromptErrorResponse) _then;

/// Create a copy of SendPromptErrorResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? message = freezed,}) {
  return _then(_SendPromptErrorResponse(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as SendPromptErrorCode,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
