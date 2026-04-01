// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session_diffs_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SessionDiffsResponse {

 List<FileDiff> get diffs;
/// Create a copy of SessionDiffsResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionDiffsResponseCopyWith<SessionDiffsResponse> get copyWith => _$SessionDiffsResponseCopyWithImpl<SessionDiffsResponse>(this as SessionDiffsResponse, _$identity);

  /// Serializes this SessionDiffsResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionDiffsResponse&&const DeepCollectionEquality().equals(other.diffs, diffs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(diffs));

@override
String toString() {
  return 'SessionDiffsResponse(diffs: $diffs)';
}


}

/// @nodoc
abstract mixin class $SessionDiffsResponseCopyWith<$Res>  {
  factory $SessionDiffsResponseCopyWith(SessionDiffsResponse value, $Res Function(SessionDiffsResponse) _then) = _$SessionDiffsResponseCopyWithImpl;
@useResult
$Res call({
 List<FileDiff> diffs
});




}
/// @nodoc
class _$SessionDiffsResponseCopyWithImpl<$Res>
    implements $SessionDiffsResponseCopyWith<$Res> {
  _$SessionDiffsResponseCopyWithImpl(this._self, this._then);

  final SessionDiffsResponse _self;
  final $Res Function(SessionDiffsResponse) _then;

/// Create a copy of SessionDiffsResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? diffs = null,}) {
  return _then(_self.copyWith(
diffs: null == diffs ? _self.diffs : diffs // ignore: cast_nullable_to_non_nullable
as List<FileDiff>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _SessionDiffsResponse implements SessionDiffsResponse {
  const _SessionDiffsResponse({required final  List<FileDiff> diffs}): _diffs = diffs;
  factory _SessionDiffsResponse.fromJson(Map<String, dynamic> json) => _$SessionDiffsResponseFromJson(json);

 final  List<FileDiff> _diffs;
@override List<FileDiff> get diffs {
  if (_diffs is EqualUnmodifiableListView) return _diffs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_diffs);
}


/// Create a copy of SessionDiffsResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionDiffsResponseCopyWith<_SessionDiffsResponse> get copyWith => __$SessionDiffsResponseCopyWithImpl<_SessionDiffsResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionDiffsResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionDiffsResponse&&const DeepCollectionEquality().equals(other._diffs, _diffs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_diffs));

@override
String toString() {
  return 'SessionDiffsResponse(diffs: $diffs)';
}


}

/// @nodoc
abstract mixin class _$SessionDiffsResponseCopyWith<$Res> implements $SessionDiffsResponseCopyWith<$Res> {
  factory _$SessionDiffsResponseCopyWith(_SessionDiffsResponse value, $Res Function(_SessionDiffsResponse) _then) = __$SessionDiffsResponseCopyWithImpl;
@override @useResult
$Res call({
 List<FileDiff> diffs
});




}
/// @nodoc
class __$SessionDiffsResponseCopyWithImpl<$Res>
    implements _$SessionDiffsResponseCopyWith<$Res> {
  __$SessionDiffsResponseCopyWithImpl(this._self, this._then);

  final _SessionDiffsResponse _self;
  final $Res Function(_SessionDiffsResponse) _then;

/// Create a copy of SessionDiffsResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? diffs = null,}) {
  return _then(_SessionDiffsResponse(
diffs: null == diffs ? _self._diffs : diffs // ignore: cast_nullable_to_non_nullable
as List<FileDiff>,
  ));
}


}

// dart format on
