// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'catalog_import_statuses_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CatalogImportStatusesResponse {

 List<CatalogImportProgress> get statuses;
/// Create a copy of CatalogImportStatusesResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CatalogImportStatusesResponseCopyWith<CatalogImportStatusesResponse> get copyWith => _$CatalogImportStatusesResponseCopyWithImpl<CatalogImportStatusesResponse>(this as CatalogImportStatusesResponse, _$identity);

  /// Serializes this CatalogImportStatusesResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CatalogImportStatusesResponse&&const DeepCollectionEquality().equals(other.statuses, statuses));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(statuses));

@override
String toString() {
  return 'CatalogImportStatusesResponse(statuses: $statuses)';
}


}

/// @nodoc
abstract mixin class $CatalogImportStatusesResponseCopyWith<$Res>  {
  factory $CatalogImportStatusesResponseCopyWith(CatalogImportStatusesResponse value, $Res Function(CatalogImportStatusesResponse) _then) = _$CatalogImportStatusesResponseCopyWithImpl;
@useResult
$Res call({
 List<CatalogImportProgress> statuses
});




}
/// @nodoc
class _$CatalogImportStatusesResponseCopyWithImpl<$Res>
    implements $CatalogImportStatusesResponseCopyWith<$Res> {
  _$CatalogImportStatusesResponseCopyWithImpl(this._self, this._then);

  final CatalogImportStatusesResponse _self;
  final $Res Function(CatalogImportStatusesResponse) _then;

/// Create a copy of CatalogImportStatusesResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? statuses = null,}) {
  return _then(_self.copyWith(
statuses: null == statuses ? _self.statuses : statuses // ignore: cast_nullable_to_non_nullable
as List<CatalogImportProgress>,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CatalogImportStatusesResponse implements CatalogImportStatusesResponse {
  const _CatalogImportStatusesResponse({required final  List<CatalogImportProgress> statuses}): _statuses = statuses;
  factory _CatalogImportStatusesResponse.fromJson(Map<String, dynamic> json) => _$CatalogImportStatusesResponseFromJson(json);

 final  List<CatalogImportProgress> _statuses;
@override List<CatalogImportProgress> get statuses {
  if (_statuses is EqualUnmodifiableListView) return _statuses;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_statuses);
}


/// Create a copy of CatalogImportStatusesResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CatalogImportStatusesResponseCopyWith<_CatalogImportStatusesResponse> get copyWith => __$CatalogImportStatusesResponseCopyWithImpl<_CatalogImportStatusesResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CatalogImportStatusesResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CatalogImportStatusesResponse&&const DeepCollectionEquality().equals(other._statuses, _statuses));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_statuses));

@override
String toString() {
  return 'CatalogImportStatusesResponse(statuses: $statuses)';
}


}

/// @nodoc
abstract mixin class _$CatalogImportStatusesResponseCopyWith<$Res> implements $CatalogImportStatusesResponseCopyWith<$Res> {
  factory _$CatalogImportStatusesResponseCopyWith(_CatalogImportStatusesResponse value, $Res Function(_CatalogImportStatusesResponse) _then) = __$CatalogImportStatusesResponseCopyWithImpl;
@override @useResult
$Res call({
 List<CatalogImportProgress> statuses
});




}
/// @nodoc
class __$CatalogImportStatusesResponseCopyWithImpl<$Res>
    implements _$CatalogImportStatusesResponseCopyWith<$Res> {
  __$CatalogImportStatusesResponseCopyWithImpl(this._self, this._then);

  final _CatalogImportStatusesResponse _self;
  final $Res Function(_CatalogImportStatusesResponse) _then;

/// Create a copy of CatalogImportStatusesResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? statuses = null,}) {
  return _then(_CatalogImportStatusesResponse(
statuses: null == statuses ? _self._statuses : statuses // ignore: cast_nullable_to_non_nullable
as List<CatalogImportProgress>,
  ));
}


}

// dart format on
