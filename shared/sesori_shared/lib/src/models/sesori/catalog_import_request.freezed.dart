// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'catalog_import_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CatalogImportRequest {

 String get pluginId;
/// Create a copy of CatalogImportRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CatalogImportRequestCopyWith<CatalogImportRequest> get copyWith => _$CatalogImportRequestCopyWithImpl<CatalogImportRequest>(this as CatalogImportRequest, _$identity);

  /// Serializes this CatalogImportRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CatalogImportRequest&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pluginId);

@override
String toString() {
  return 'CatalogImportRequest(pluginId: $pluginId)';
}


}

/// @nodoc
abstract mixin class $CatalogImportRequestCopyWith<$Res>  {
  factory $CatalogImportRequestCopyWith(CatalogImportRequest value, $Res Function(CatalogImportRequest) _then) = _$CatalogImportRequestCopyWithImpl;
@useResult
$Res call({
 String pluginId
});




}
/// @nodoc
class _$CatalogImportRequestCopyWithImpl<$Res>
    implements $CatalogImportRequestCopyWith<$Res> {
  _$CatalogImportRequestCopyWithImpl(this._self, this._then);

  final CatalogImportRequest _self;
  final $Res Function(CatalogImportRequest) _then;

/// Create a copy of CatalogImportRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pluginId = null,}) {
  return _then(_self.copyWith(
pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _CatalogImportRequest implements CatalogImportRequest {
  const _CatalogImportRequest({required this.pluginId});
  factory _CatalogImportRequest.fromJson(Map<String, dynamic> json) => _$CatalogImportRequestFromJson(json);

@override final  String pluginId;

/// Create a copy of CatalogImportRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CatalogImportRequestCopyWith<_CatalogImportRequest> get copyWith => __$CatalogImportRequestCopyWithImpl<_CatalogImportRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CatalogImportRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CatalogImportRequest&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pluginId);

@override
String toString() {
  return 'CatalogImportRequest(pluginId: $pluginId)';
}


}

/// @nodoc
abstract mixin class _$CatalogImportRequestCopyWith<$Res> implements $CatalogImportRequestCopyWith<$Res> {
  factory _$CatalogImportRequestCopyWith(_CatalogImportRequest value, $Res Function(_CatalogImportRequest) _then) = __$CatalogImportRequestCopyWithImpl;
@override @useResult
$Res call({
 String pluginId
});




}
/// @nodoc
class __$CatalogImportRequestCopyWithImpl<$Res>
    implements _$CatalogImportRequestCopyWith<$Res> {
  __$CatalogImportRequestCopyWithImpl(this._self, this._then);

  final _CatalogImportRequest _self;
  final $Res Function(_CatalogImportRequest) _then;

/// Create a copy of CatalogImportRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pluginId = null,}) {
  return _then(_CatalogImportRequest(
pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
