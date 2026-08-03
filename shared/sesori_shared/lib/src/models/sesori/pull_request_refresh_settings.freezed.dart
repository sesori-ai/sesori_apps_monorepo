// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pull_request_refresh_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PullRequestRefreshSettingsRequest {

@JsonKey(fromJson: _strictIntFromJson) int get intervalSeconds;
/// Create a copy of PullRequestRefreshSettingsRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PullRequestRefreshSettingsRequestCopyWith<PullRequestRefreshSettingsRequest> get copyWith => _$PullRequestRefreshSettingsRequestCopyWithImpl<PullRequestRefreshSettingsRequest>(this as PullRequestRefreshSettingsRequest, _$identity);

  /// Serializes this PullRequestRefreshSettingsRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestRefreshSettingsRequest&&(identical(other.intervalSeconds, intervalSeconds) || other.intervalSeconds == intervalSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,intervalSeconds);

@override
String toString() {
  return 'PullRequestRefreshSettingsRequest(intervalSeconds: $intervalSeconds)';
}


}

/// @nodoc
abstract mixin class $PullRequestRefreshSettingsRequestCopyWith<$Res>  {
  factory $PullRequestRefreshSettingsRequestCopyWith(PullRequestRefreshSettingsRequest value, $Res Function(PullRequestRefreshSettingsRequest) _then) = _$PullRequestRefreshSettingsRequestCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _strictIntFromJson) int intervalSeconds
});




}
/// @nodoc
class _$PullRequestRefreshSettingsRequestCopyWithImpl<$Res>
    implements $PullRequestRefreshSettingsRequestCopyWith<$Res> {
  _$PullRequestRefreshSettingsRequestCopyWithImpl(this._self, this._then);

  final PullRequestRefreshSettingsRequest _self;
  final $Res Function(PullRequestRefreshSettingsRequest) _then;

/// Create a copy of PullRequestRefreshSettingsRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? intervalSeconds = null,}) {
  return _then(_self.copyWith(
intervalSeconds: null == intervalSeconds ? _self.intervalSeconds : intervalSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PullRequestRefreshSettingsRequest implements PullRequestRefreshSettingsRequest {
  const _PullRequestRefreshSettingsRequest({@JsonKey(fromJson: _strictIntFromJson) required this.intervalSeconds});
  factory _PullRequestRefreshSettingsRequest.fromJson(Map<String, dynamic> json) => _$PullRequestRefreshSettingsRequestFromJson(json);

@override@JsonKey(fromJson: _strictIntFromJson) final  int intervalSeconds;

/// Create a copy of PullRequestRefreshSettingsRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PullRequestRefreshSettingsRequestCopyWith<_PullRequestRefreshSettingsRequest> get copyWith => __$PullRequestRefreshSettingsRequestCopyWithImpl<_PullRequestRefreshSettingsRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PullRequestRefreshSettingsRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PullRequestRefreshSettingsRequest&&(identical(other.intervalSeconds, intervalSeconds) || other.intervalSeconds == intervalSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,intervalSeconds);

@override
String toString() {
  return 'PullRequestRefreshSettingsRequest(intervalSeconds: $intervalSeconds)';
}


}

/// @nodoc
abstract mixin class _$PullRequestRefreshSettingsRequestCopyWith<$Res> implements $PullRequestRefreshSettingsRequestCopyWith<$Res> {
  factory _$PullRequestRefreshSettingsRequestCopyWith(_PullRequestRefreshSettingsRequest value, $Res Function(_PullRequestRefreshSettingsRequest) _then) = __$PullRequestRefreshSettingsRequestCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _strictIntFromJson) int intervalSeconds
});




}
/// @nodoc
class __$PullRequestRefreshSettingsRequestCopyWithImpl<$Res>
    implements _$PullRequestRefreshSettingsRequestCopyWith<$Res> {
  __$PullRequestRefreshSettingsRequestCopyWithImpl(this._self, this._then);

  final _PullRequestRefreshSettingsRequest _self;
  final $Res Function(_PullRequestRefreshSettingsRequest) _then;

/// Create a copy of PullRequestRefreshSettingsRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? intervalSeconds = null,}) {
  return _then(_PullRequestRefreshSettingsRequest(
intervalSeconds: null == intervalSeconds ? _self.intervalSeconds : intervalSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$PullRequestRefreshSettingsResponse {

@JsonKey(fromJson: _strictIntFromJson) int get intervalSeconds;
/// Create a copy of PullRequestRefreshSettingsResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PullRequestRefreshSettingsResponseCopyWith<PullRequestRefreshSettingsResponse> get copyWith => _$PullRequestRefreshSettingsResponseCopyWithImpl<PullRequestRefreshSettingsResponse>(this as PullRequestRefreshSettingsResponse, _$identity);

  /// Serializes this PullRequestRefreshSettingsResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestRefreshSettingsResponse&&(identical(other.intervalSeconds, intervalSeconds) || other.intervalSeconds == intervalSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,intervalSeconds);

@override
String toString() {
  return 'PullRequestRefreshSettingsResponse(intervalSeconds: $intervalSeconds)';
}


}

/// @nodoc
abstract mixin class $PullRequestRefreshSettingsResponseCopyWith<$Res>  {
  factory $PullRequestRefreshSettingsResponseCopyWith(PullRequestRefreshSettingsResponse value, $Res Function(PullRequestRefreshSettingsResponse) _then) = _$PullRequestRefreshSettingsResponseCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _strictIntFromJson) int intervalSeconds
});




}
/// @nodoc
class _$PullRequestRefreshSettingsResponseCopyWithImpl<$Res>
    implements $PullRequestRefreshSettingsResponseCopyWith<$Res> {
  _$PullRequestRefreshSettingsResponseCopyWithImpl(this._self, this._then);

  final PullRequestRefreshSettingsResponse _self;
  final $Res Function(PullRequestRefreshSettingsResponse) _then;

/// Create a copy of PullRequestRefreshSettingsResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? intervalSeconds = null,}) {
  return _then(_self.copyWith(
intervalSeconds: null == intervalSeconds ? _self.intervalSeconds : intervalSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PullRequestRefreshSettingsResponse implements PullRequestRefreshSettingsResponse {
  const _PullRequestRefreshSettingsResponse({@JsonKey(fromJson: _strictIntFromJson) required this.intervalSeconds});
  factory _PullRequestRefreshSettingsResponse.fromJson(Map<String, dynamic> json) => _$PullRequestRefreshSettingsResponseFromJson(json);

@override@JsonKey(fromJson: _strictIntFromJson) final  int intervalSeconds;

/// Create a copy of PullRequestRefreshSettingsResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PullRequestRefreshSettingsResponseCopyWith<_PullRequestRefreshSettingsResponse> get copyWith => __$PullRequestRefreshSettingsResponseCopyWithImpl<_PullRequestRefreshSettingsResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PullRequestRefreshSettingsResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PullRequestRefreshSettingsResponse&&(identical(other.intervalSeconds, intervalSeconds) || other.intervalSeconds == intervalSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,intervalSeconds);

@override
String toString() {
  return 'PullRequestRefreshSettingsResponse(intervalSeconds: $intervalSeconds)';
}


}

/// @nodoc
abstract mixin class _$PullRequestRefreshSettingsResponseCopyWith<$Res> implements $PullRequestRefreshSettingsResponseCopyWith<$Res> {
  factory _$PullRequestRefreshSettingsResponseCopyWith(_PullRequestRefreshSettingsResponse value, $Res Function(_PullRequestRefreshSettingsResponse) _then) = __$PullRequestRefreshSettingsResponseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _strictIntFromJson) int intervalSeconds
});




}
/// @nodoc
class __$PullRequestRefreshSettingsResponseCopyWithImpl<$Res>
    implements _$PullRequestRefreshSettingsResponseCopyWith<$Res> {
  __$PullRequestRefreshSettingsResponseCopyWithImpl(this._self, this._then);

  final _PullRequestRefreshSettingsResponse _self;
  final $Res Function(_PullRequestRefreshSettingsResponse) _then;

/// Create a copy of PullRequestRefreshSettingsResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? intervalSeconds = null,}) {
  return _then(_PullRequestRefreshSettingsResponse(
intervalSeconds: null == intervalSeconds ? _self.intervalSeconds : intervalSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$PullRequestRefreshSettingsErrorResponse {

@JsonKey(unknownEnumValue: PullRequestRefreshSettingsErrorCode.unknown) PullRequestRefreshSettingsErrorCode get code;@JsonKey(fromJson: _strictIntFromJson) int get minimumIntervalSeconds;@JsonKey(fromJson: _strictIntFromJson) int get maximumIntervalSeconds;
/// Create a copy of PullRequestRefreshSettingsErrorResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PullRequestRefreshSettingsErrorResponseCopyWith<PullRequestRefreshSettingsErrorResponse> get copyWith => _$PullRequestRefreshSettingsErrorResponseCopyWithImpl<PullRequestRefreshSettingsErrorResponse>(this as PullRequestRefreshSettingsErrorResponse, _$identity);

  /// Serializes this PullRequestRefreshSettingsErrorResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PullRequestRefreshSettingsErrorResponse&&(identical(other.code, code) || other.code == code)&&(identical(other.minimumIntervalSeconds, minimumIntervalSeconds) || other.minimumIntervalSeconds == minimumIntervalSeconds)&&(identical(other.maximumIntervalSeconds, maximumIntervalSeconds) || other.maximumIntervalSeconds == maximumIntervalSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,minimumIntervalSeconds,maximumIntervalSeconds);

@override
String toString() {
  return 'PullRequestRefreshSettingsErrorResponse(code: $code, minimumIntervalSeconds: $minimumIntervalSeconds, maximumIntervalSeconds: $maximumIntervalSeconds)';
}


}

/// @nodoc
abstract mixin class $PullRequestRefreshSettingsErrorResponseCopyWith<$Res>  {
  factory $PullRequestRefreshSettingsErrorResponseCopyWith(PullRequestRefreshSettingsErrorResponse value, $Res Function(PullRequestRefreshSettingsErrorResponse) _then) = _$PullRequestRefreshSettingsErrorResponseCopyWithImpl;
@useResult
$Res call({
@JsonKey(unknownEnumValue: PullRequestRefreshSettingsErrorCode.unknown) PullRequestRefreshSettingsErrorCode code,@JsonKey(fromJson: _strictIntFromJson) int minimumIntervalSeconds,@JsonKey(fromJson: _strictIntFromJson) int maximumIntervalSeconds
});




}
/// @nodoc
class _$PullRequestRefreshSettingsErrorResponseCopyWithImpl<$Res>
    implements $PullRequestRefreshSettingsErrorResponseCopyWith<$Res> {
  _$PullRequestRefreshSettingsErrorResponseCopyWithImpl(this._self, this._then);

  final PullRequestRefreshSettingsErrorResponse _self;
  final $Res Function(PullRequestRefreshSettingsErrorResponse) _then;

/// Create a copy of PullRequestRefreshSettingsErrorResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? code = null,Object? minimumIntervalSeconds = null,Object? maximumIntervalSeconds = null,}) {
  return _then(_self.copyWith(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as PullRequestRefreshSettingsErrorCode,minimumIntervalSeconds: null == minimumIntervalSeconds ? _self.minimumIntervalSeconds : minimumIntervalSeconds // ignore: cast_nullable_to_non_nullable
as int,maximumIntervalSeconds: null == maximumIntervalSeconds ? _self.maximumIntervalSeconds : maximumIntervalSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PullRequestRefreshSettingsErrorResponse implements PullRequestRefreshSettingsErrorResponse {
  const _PullRequestRefreshSettingsErrorResponse({@JsonKey(unknownEnumValue: PullRequestRefreshSettingsErrorCode.unknown) required this.code, @JsonKey(fromJson: _strictIntFromJson) required this.minimumIntervalSeconds, @JsonKey(fromJson: _strictIntFromJson) required this.maximumIntervalSeconds});
  factory _PullRequestRefreshSettingsErrorResponse.fromJson(Map<String, dynamic> json) => _$PullRequestRefreshSettingsErrorResponseFromJson(json);

@override@JsonKey(unknownEnumValue: PullRequestRefreshSettingsErrorCode.unknown) final  PullRequestRefreshSettingsErrorCode code;
@override@JsonKey(fromJson: _strictIntFromJson) final  int minimumIntervalSeconds;
@override@JsonKey(fromJson: _strictIntFromJson) final  int maximumIntervalSeconds;

/// Create a copy of PullRequestRefreshSettingsErrorResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PullRequestRefreshSettingsErrorResponseCopyWith<_PullRequestRefreshSettingsErrorResponse> get copyWith => __$PullRequestRefreshSettingsErrorResponseCopyWithImpl<_PullRequestRefreshSettingsErrorResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PullRequestRefreshSettingsErrorResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PullRequestRefreshSettingsErrorResponse&&(identical(other.code, code) || other.code == code)&&(identical(other.minimumIntervalSeconds, minimumIntervalSeconds) || other.minimumIntervalSeconds == minimumIntervalSeconds)&&(identical(other.maximumIntervalSeconds, maximumIntervalSeconds) || other.maximumIntervalSeconds == maximumIntervalSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,code,minimumIntervalSeconds,maximumIntervalSeconds);

@override
String toString() {
  return 'PullRequestRefreshSettingsErrorResponse(code: $code, minimumIntervalSeconds: $minimumIntervalSeconds, maximumIntervalSeconds: $maximumIntervalSeconds)';
}


}

/// @nodoc
abstract mixin class _$PullRequestRefreshSettingsErrorResponseCopyWith<$Res> implements $PullRequestRefreshSettingsErrorResponseCopyWith<$Res> {
  factory _$PullRequestRefreshSettingsErrorResponseCopyWith(_PullRequestRefreshSettingsErrorResponse value, $Res Function(_PullRequestRefreshSettingsErrorResponse) _then) = __$PullRequestRefreshSettingsErrorResponseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(unknownEnumValue: PullRequestRefreshSettingsErrorCode.unknown) PullRequestRefreshSettingsErrorCode code,@JsonKey(fromJson: _strictIntFromJson) int minimumIntervalSeconds,@JsonKey(fromJson: _strictIntFromJson) int maximumIntervalSeconds
});




}
/// @nodoc
class __$PullRequestRefreshSettingsErrorResponseCopyWithImpl<$Res>
    implements _$PullRequestRefreshSettingsErrorResponseCopyWith<$Res> {
  __$PullRequestRefreshSettingsErrorResponseCopyWithImpl(this._self, this._then);

  final _PullRequestRefreshSettingsErrorResponse _self;
  final $Res Function(_PullRequestRefreshSettingsErrorResponse) _then;

/// Create a copy of PullRequestRefreshSettingsErrorResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? code = null,Object? minimumIntervalSeconds = null,Object? maximumIntervalSeconds = null,}) {
  return _then(_PullRequestRefreshSettingsErrorResponse(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as PullRequestRefreshSettingsErrorCode,minimumIntervalSeconds: null == minimumIntervalSeconds ? _self.minimumIntervalSeconds : minimumIntervalSeconds // ignore: cast_nullable_to_non_nullable
as int,maximumIntervalSeconds: null == maximumIntervalSeconds ? _self.maximumIntervalSeconds : maximumIntervalSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
