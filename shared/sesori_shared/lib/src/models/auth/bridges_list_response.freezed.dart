// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bridges_list_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BridgesListResponse {

 List<BridgeSummary> get bridges;
/// Create a copy of BridgesListResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgesListResponseCopyWith<BridgesListResponse> get copyWith => _$BridgesListResponseCopyWithImpl<BridgesListResponse>(this as BridgesListResponse, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgesListResponse&&const DeepCollectionEquality().equals(other.bridges, bridges));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(bridges));

@override
String toString() {
  return 'BridgesListResponse(bridges: $bridges)';
}


}

/// @nodoc
abstract mixin class $BridgesListResponseCopyWith<$Res>  {
  factory $BridgesListResponseCopyWith(BridgesListResponse value, $Res Function(BridgesListResponse) _then) = _$BridgesListResponseCopyWithImpl;
@useResult
$Res call({
 List<BridgeSummary> bridges
});




}
/// @nodoc
class _$BridgesListResponseCopyWithImpl<$Res>
    implements $BridgesListResponseCopyWith<$Res> {
  _$BridgesListResponseCopyWithImpl(this._self, this._then);

  final BridgesListResponse _self;
  final $Res Function(BridgesListResponse) _then;

/// Create a copy of BridgesListResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bridges = null,}) {
  return _then(_self.copyWith(
bridges: null == bridges ? _self.bridges : bridges // ignore: cast_nullable_to_non_nullable
as List<BridgeSummary>,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _BridgesListResponse implements BridgesListResponse {
  const _BridgesListResponse({required final  List<BridgeSummary> bridges}): _bridges = bridges;
  factory _BridgesListResponse.fromJson(Map<String, dynamic> json) => _$BridgesListResponseFromJson(json);

 final  List<BridgeSummary> _bridges;
@override List<BridgeSummary> get bridges {
  if (_bridges is EqualUnmodifiableListView) return _bridges;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_bridges);
}


/// Create a copy of BridgesListResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BridgesListResponseCopyWith<_BridgesListResponse> get copyWith => __$BridgesListResponseCopyWithImpl<_BridgesListResponse>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BridgesListResponse&&const DeepCollectionEquality().equals(other._bridges, _bridges));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_bridges));

@override
String toString() {
  return 'BridgesListResponse(bridges: $bridges)';
}


}

/// @nodoc
abstract mixin class _$BridgesListResponseCopyWith<$Res> implements $BridgesListResponseCopyWith<$Res> {
  factory _$BridgesListResponseCopyWith(_BridgesListResponse value, $Res Function(_BridgesListResponse) _then) = __$BridgesListResponseCopyWithImpl;
@override @useResult
$Res call({
 List<BridgeSummary> bridges
});




}
/// @nodoc
class __$BridgesListResponseCopyWithImpl<$Res>
    implements _$BridgesListResponseCopyWith<$Res> {
  __$BridgesListResponseCopyWithImpl(this._self, this._then);

  final _BridgesListResponse _self;
  final $Res Function(_BridgesListResponse) _then;

/// Create a copy of BridgesListResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bridges = null,}) {
  return _then(_BridgesListResponse(
bridges: null == bridges ? _self._bridges : bridges // ignore: cast_nullable_to_non_nullable
as List<BridgeSummary>,
  ));
}


}

// dart format on
