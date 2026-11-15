// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_branch_error_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SessionBranchErrorResponse {

@JsonKey(unknownEnumValue: SessionBranchErrorCode.unknown) SessionBranchErrorCode get code; String? get message;
/// Create a copy of SessionBranchErrorResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionBranchErrorResponseCopyWith<SessionBranchErrorResponse> get copyWith => _$SessionBranchErrorResponseCopyWithImpl<SessionBranchErrorResponse>(this as SessionBranchErrorResponse, _$identity);

  /// Serializes this SessionBranchErrorResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SessionBranchErrorResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionBranchErrorResponse&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.message, _this.message) || other.message == _this.message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SessionBranchErrorResponse;
  return Object.hash(runtimeType,_this.code,_this.message);
}

@override
String toString() {
  final _this = this as SessionBranchErrorResponse;
  return 'SessionBranchErrorResponse(code: ${_this.code}, message: ${_this.message})';
}


}

/// @nodoc
abstract mixin class $SessionBranchErrorResponseCopyWith<$Res>  {
  factory $SessionBranchErrorResponseCopyWith(SessionBranchErrorResponse value, $Res Function(SessionBranchErrorResponse) _then) = _$SessionBranchErrorResponseCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: SessionBranchErrorCode.unknown) SessionBranchErrorCode code, String? message
});




}
/// @nodoc
class _$SessionBranchErrorResponseCopyWithImpl<$Res>
    implements $SessionBranchErrorResponseCopyWith<$Res> {
  _$SessionBranchErrorResponseCopyWithImpl(this._self, this._then);

  final SessionBranchErrorResponse _self;
  final $Res Function(SessionBranchErrorResponse) _then;

/// Create a copy of SessionBranchErrorResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? message = freezed,}) {
  return _then(SessionBranchErrorResponse(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as SessionBranchErrorCode,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SessionBranchErrorResponse implements SessionBranchErrorResponse {
  const _SessionBranchErrorResponse({@JsonKey(unknownEnumValue: SessionBranchErrorCode.unknown) required this.code, required this.message});
  factory _SessionBranchErrorResponse.fromJson(Map<String, dynamic> json) => _$SessionBranchErrorResponseFromJson(json);

@override@JsonKey(unknownEnumValue: SessionBranchErrorCode.unknown) final  SessionBranchErrorCode code;
@override final  String? message;

/// Create a copy of SessionBranchErrorResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionBranchErrorResponseCopyWith<_SessionBranchErrorResponse> get copyWith => __$SessionBranchErrorResponseCopyWithImpl<_SessionBranchErrorResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionBranchErrorResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionBranchErrorResponse&&(identical(other.code, code) || other.code == code)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,code,message);
}

@override
String toString() {
    return 'SessionBranchErrorResponse(code: $code, message: $message)';
}


}

/// @nodoc
abstract mixin class _$SessionBranchErrorResponseCopyWith<$Res> implements $SessionBranchErrorResponseCopyWith<$Res> {
  factory _$SessionBranchErrorResponseCopyWith(_SessionBranchErrorResponse value, $Res Function(_SessionBranchErrorResponse) _then) = __$SessionBranchErrorResponseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: SessionBranchErrorCode.unknown) SessionBranchErrorCode code, String? message
});




}
/// @nodoc
class __$SessionBranchErrorResponseCopyWithImpl<$Res>
    implements _$SessionBranchErrorResponseCopyWith<$Res> {
  __$SessionBranchErrorResponseCopyWithImpl(this._self, this._then);

  final _SessionBranchErrorResponse _self;
  final $Res Function(_SessionBranchErrorResponse) _then;

/// Create a copy of SessionBranchErrorResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? message = freezed,}) {
  return _then(_SessionBranchErrorResponse(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as SessionBranchErrorCode,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
