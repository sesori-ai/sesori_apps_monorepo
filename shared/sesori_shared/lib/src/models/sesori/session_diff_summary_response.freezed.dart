// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_diff_summary_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SessionDiffSummaryResponse {

 int get additions; int get deletions;
/// Create a copy of SessionDiffSummaryResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionDiffSummaryResponseCopyWith<SessionDiffSummaryResponse> get copyWith => _$SessionDiffSummaryResponseCopyWithImpl<SessionDiffSummaryResponse>(this as SessionDiffSummaryResponse, _$identity);

  /// Serializes this SessionDiffSummaryResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SessionDiffSummaryResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionDiffSummaryResponse&&(identical(other.additions, _this.additions) || other.additions == _this.additions)&&(identical(other.deletions, _this.deletions) || other.deletions == _this.deletions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SessionDiffSummaryResponse;
  return Object.hash(runtimeType,_this.additions,_this.deletions);
}

@override
String toString() {
  final _this = this as SessionDiffSummaryResponse;
  return 'SessionDiffSummaryResponse(additions: ${_this.additions}, deletions: ${_this.deletions})';
}


}

/// @nodoc
abstract mixin class $SessionDiffSummaryResponseCopyWith<$Res>  {
  factory $SessionDiffSummaryResponseCopyWith(SessionDiffSummaryResponse value, $Res Function(SessionDiffSummaryResponse) _then) = _$SessionDiffSummaryResponseCopyWithImpl;
@useResult
$Res call({
 int additions, int deletions
});




}
/// @nodoc
class _$SessionDiffSummaryResponseCopyWithImpl<$Res>
    implements $SessionDiffSummaryResponseCopyWith<$Res> {
  _$SessionDiffSummaryResponseCopyWithImpl(this._self, this._then);

  final SessionDiffSummaryResponse _self;
  final $Res Function(SessionDiffSummaryResponse) _then;

/// Create a copy of SessionDiffSummaryResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? additions = null,Object? deletions = null,}) {
  return _then(SessionDiffSummaryResponse(
additions: null == additions ? _self.additions : additions // ignore: cast_nullable_to_non_nullable
as int,deletions: null == deletions ? _self.deletions : deletions // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SessionDiffSummaryResponse implements SessionDiffSummaryResponse {
  const _SessionDiffSummaryResponse({required this.additions, required this.deletions});
  factory _SessionDiffSummaryResponse.fromJson(Map<String, dynamic> json) => _$SessionDiffSummaryResponseFromJson(json);

@override final  int additions;
@override final  int deletions;

/// Create a copy of SessionDiffSummaryResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionDiffSummaryResponseCopyWith<_SessionDiffSummaryResponse> get copyWith => __$SessionDiffSummaryResponseCopyWithImpl<_SessionDiffSummaryResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionDiffSummaryResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionDiffSummaryResponse&&(identical(other.additions, additions) || other.additions == additions)&&(identical(other.deletions, deletions) || other.deletions == deletions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,additions,deletions);
}

@override
String toString() {
    return 'SessionDiffSummaryResponse(additions: $additions, deletions: $deletions)';
}


}

/// @nodoc
abstract mixin class _$SessionDiffSummaryResponseCopyWith<$Res> implements $SessionDiffSummaryResponseCopyWith<$Res> {
  factory _$SessionDiffSummaryResponseCopyWith(_SessionDiffSummaryResponse value, $Res Function(_SessionDiffSummaryResponse) _then) = __$SessionDiffSummaryResponseCopyWithImpl;
@override @useResult
$Res call({
 int additions, int deletions
});




}
/// @nodoc
class __$SessionDiffSummaryResponseCopyWithImpl<$Res>
    implements _$SessionDiffSummaryResponseCopyWith<$Res> {
  __$SessionDiffSummaryResponseCopyWithImpl(this._self, this._then);

  final _SessionDiffSummaryResponse _self;
  final $Res Function(_SessionDiffSummaryResponse) _then;

/// Create a copy of SessionDiffSummaryResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? additions = null,Object? deletions = null,}) {
  return _then(_SessionDiffSummaryResponse(
additions: null == additions ? _self.additions : additions // ignore: cast_nullable_to_non_nullable
as int,deletions: null == deletions ? _self.deletions : deletions // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$SessionDiffSummaryErrorResponse {

@JsonKey(unknownEnumValue: SessionDiffSummaryErrorCode.unknown) SessionDiffSummaryErrorCode get code;
/// Create a copy of SessionDiffSummaryErrorResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionDiffSummaryErrorResponseCopyWith<SessionDiffSummaryErrorResponse> get copyWith => _$SessionDiffSummaryErrorResponseCopyWithImpl<SessionDiffSummaryErrorResponse>(this as SessionDiffSummaryErrorResponse, _$identity);

  /// Serializes this SessionDiffSummaryErrorResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SessionDiffSummaryErrorResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionDiffSummaryErrorResponse&&(identical(other.code, _this.code) || other.code == _this.code));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SessionDiffSummaryErrorResponse;
  return Object.hash(runtimeType,_this.code);
}

@override
String toString() {
  final _this = this as SessionDiffSummaryErrorResponse;
  return 'SessionDiffSummaryErrorResponse(code: ${_this.code})';
}


}

/// @nodoc
abstract mixin class $SessionDiffSummaryErrorResponseCopyWith<$Res>  {
  factory $SessionDiffSummaryErrorResponseCopyWith(SessionDiffSummaryErrorResponse value, $Res Function(SessionDiffSummaryErrorResponse) _then) = _$SessionDiffSummaryErrorResponseCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: SessionDiffSummaryErrorCode.unknown) SessionDiffSummaryErrorCode code
});




}
/// @nodoc
class _$SessionDiffSummaryErrorResponseCopyWithImpl<$Res>
    implements $SessionDiffSummaryErrorResponseCopyWith<$Res> {
  _$SessionDiffSummaryErrorResponseCopyWithImpl(this._self, this._then);

  final SessionDiffSummaryErrorResponse _self;
  final $Res Function(SessionDiffSummaryErrorResponse) _then;

/// Create a copy of SessionDiffSummaryErrorResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,}) {
  return _then(SessionDiffSummaryErrorResponse(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as SessionDiffSummaryErrorCode,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SessionDiffSummaryErrorResponse implements SessionDiffSummaryErrorResponse {
  const _SessionDiffSummaryErrorResponse({@JsonKey(unknownEnumValue: SessionDiffSummaryErrorCode.unknown) required this.code});
  factory _SessionDiffSummaryErrorResponse.fromJson(Map<String, dynamic> json) => _$SessionDiffSummaryErrorResponseFromJson(json);

@override@JsonKey(unknownEnumValue: SessionDiffSummaryErrorCode.unknown) final  SessionDiffSummaryErrorCode code;

/// Create a copy of SessionDiffSummaryErrorResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionDiffSummaryErrorResponseCopyWith<_SessionDiffSummaryErrorResponse> get copyWith => __$SessionDiffSummaryErrorResponseCopyWithImpl<_SessionDiffSummaryErrorResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionDiffSummaryErrorResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionDiffSummaryErrorResponse&&(identical(other.code, code) || other.code == code));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,code);
}

@override
String toString() {
    return 'SessionDiffSummaryErrorResponse(code: $code)';
}


}

/// @nodoc
abstract mixin class _$SessionDiffSummaryErrorResponseCopyWith<$Res> implements $SessionDiffSummaryErrorResponseCopyWith<$Res> {
  factory _$SessionDiffSummaryErrorResponseCopyWith(_SessionDiffSummaryErrorResponse value, $Res Function(_SessionDiffSummaryErrorResponse) _then) = __$SessionDiffSummaryErrorResponseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: SessionDiffSummaryErrorCode.unknown) SessionDiffSummaryErrorCode code
});




}
/// @nodoc
class __$SessionDiffSummaryErrorResponseCopyWithImpl<$Res>
    implements _$SessionDiffSummaryErrorResponseCopyWith<$Res> {
  __$SessionDiffSummaryErrorResponseCopyWithImpl(this._self, this._then);

  final _SessionDiffSummaryErrorResponse _self;
  final $Res Function(_SessionDiffSummaryErrorResponse) _then;

/// Create a copy of SessionDiffSummaryErrorResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,}) {
  return _then(_SessionDiffSummaryErrorResponse(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as SessionDiffSummaryErrorCode,
  ));
}


}

// dart format on
