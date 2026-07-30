// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_options_error_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SessionOptionsErrorResponse {

@JsonKey(unknownEnumValue: SessionOptionsErrorCode.unknown) SessionOptionsErrorCode get code;
/// Create a copy of SessionOptionsErrorResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionOptionsErrorResponseCopyWith<SessionOptionsErrorResponse> get copyWith => _$SessionOptionsErrorResponseCopyWithImpl<SessionOptionsErrorResponse>(this as SessionOptionsErrorResponse, _$identity);

  /// Serializes this SessionOptionsErrorResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionOptionsErrorResponse&&(identical(other.code, code) || other.code == code));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code);

@override
String toString() {
  return 'SessionOptionsErrorResponse(code: $code)';
}


}

/// @nodoc
abstract mixin class $SessionOptionsErrorResponseCopyWith<$Res>  {
  factory $SessionOptionsErrorResponseCopyWith(SessionOptionsErrorResponse value, $Res Function(SessionOptionsErrorResponse) _then) = _$SessionOptionsErrorResponseCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: SessionOptionsErrorCode.unknown) SessionOptionsErrorCode code
});




}
/// @nodoc
class _$SessionOptionsErrorResponseCopyWithImpl<$Res>
    implements $SessionOptionsErrorResponseCopyWith<$Res> {
  _$SessionOptionsErrorResponseCopyWithImpl(this._self, this._then);

  final SessionOptionsErrorResponse _self;
  final $Res Function(SessionOptionsErrorResponse) _then;

/// Create a copy of SessionOptionsErrorResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,}) {
  return _then(_self.copyWith(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as SessionOptionsErrorCode,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SessionOptionsErrorResponse implements SessionOptionsErrorResponse {
  const _SessionOptionsErrorResponse({@JsonKey(unknownEnumValue: SessionOptionsErrorCode.unknown) required this.code});
  factory _SessionOptionsErrorResponse.fromJson(Map<String, dynamic> json) => _$SessionOptionsErrorResponseFromJson(json);

@override@JsonKey(unknownEnumValue: SessionOptionsErrorCode.unknown) final  SessionOptionsErrorCode code;

/// Create a copy of SessionOptionsErrorResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionOptionsErrorResponseCopyWith<_SessionOptionsErrorResponse> get copyWith => __$SessionOptionsErrorResponseCopyWithImpl<_SessionOptionsErrorResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionOptionsErrorResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionOptionsErrorResponse&&(identical(other.code, code) || other.code == code));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code);

@override
String toString() {
  return 'SessionOptionsErrorResponse(code: $code)';
}


}

/// @nodoc
abstract mixin class _$SessionOptionsErrorResponseCopyWith<$Res> implements $SessionOptionsErrorResponseCopyWith<$Res> {
  factory _$SessionOptionsErrorResponseCopyWith(_SessionOptionsErrorResponse value, $Res Function(_SessionOptionsErrorResponse) _then) = __$SessionOptionsErrorResponseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: SessionOptionsErrorCode.unknown) SessionOptionsErrorCode code
});




}
/// @nodoc
class __$SessionOptionsErrorResponseCopyWithImpl<$Res>
    implements _$SessionOptionsErrorResponseCopyWith<$Res> {
  __$SessionOptionsErrorResponseCopyWithImpl(this._self, this._then);

  final _SessionOptionsErrorResponse _self;
  final $Res Function(_SessionOptionsErrorResponse) _then;

/// Create a copy of SessionOptionsErrorResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,}) {
  return _then(_SessionOptionsErrorResponse(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as SessionOptionsErrorCode,
  ));
}


}

// dart format on
