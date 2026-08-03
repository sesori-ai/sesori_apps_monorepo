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

// dart format on
