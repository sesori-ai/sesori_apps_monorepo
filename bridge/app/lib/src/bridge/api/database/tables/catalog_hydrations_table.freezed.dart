// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'catalog_hydrations_table.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CatalogHydrationDto {

 String get pluginId; int get projectionVersion; int get completedAt;
/// Create a copy of CatalogHydrationDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CatalogHydrationDtoCopyWith<CatalogHydrationDto> get copyWith => _$CatalogHydrationDtoCopyWithImpl<CatalogHydrationDto>(this as CatalogHydrationDto, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CatalogHydrationDto&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.projectionVersion, projectionVersion) || other.projectionVersion == projectionVersion)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}


@override
int get hashCode => Object.hash(runtimeType,pluginId,projectionVersion,completedAt);

@override
String toString() {
  return 'CatalogHydrationDto(pluginId: $pluginId, projectionVersion: $projectionVersion, completedAt: $completedAt)';
}


}

/// @nodoc
abstract mixin class $CatalogHydrationDtoCopyWith<$Res>  {
  factory $CatalogHydrationDtoCopyWith(CatalogHydrationDto value, $Res Function(CatalogHydrationDto) _then) = _$CatalogHydrationDtoCopyWithImpl;
@useResult
$Res call({
 String pluginId, int projectionVersion, int completedAt
});




}
/// @nodoc
class _$CatalogHydrationDtoCopyWithImpl<$Res>
    implements $CatalogHydrationDtoCopyWith<$Res> {
  _$CatalogHydrationDtoCopyWithImpl(this._self, this._then);

  final CatalogHydrationDto _self;
  final $Res Function(CatalogHydrationDto) _then;

/// Create a copy of CatalogHydrationDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pluginId = null,Object? projectionVersion = null,Object? completedAt = null,}) {
  return _then(_self.copyWith(
pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,projectionVersion: null == projectionVersion ? _self.projectionVersion : projectionVersion // ignore: cast_nullable_to_non_nullable
as int,completedAt: null == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}



/// @nodoc


class _CatalogHydrationDto extends CatalogHydrationDto {
  const _CatalogHydrationDto({required this.pluginId, required this.projectionVersion, required this.completedAt}): super._();
  

@override final  String pluginId;
@override final  int projectionVersion;
@override final  int completedAt;

/// Create a copy of CatalogHydrationDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CatalogHydrationDtoCopyWith<_CatalogHydrationDto> get copyWith => __$CatalogHydrationDtoCopyWithImpl<_CatalogHydrationDto>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CatalogHydrationDto&&(identical(other.pluginId, pluginId) || other.pluginId == pluginId)&&(identical(other.projectionVersion, projectionVersion) || other.projectionVersion == projectionVersion)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}


@override
int get hashCode => Object.hash(runtimeType,pluginId,projectionVersion,completedAt);

@override
String toString() {
  return 'CatalogHydrationDto(pluginId: $pluginId, projectionVersion: $projectionVersion, completedAt: $completedAt)';
}


}

/// @nodoc
abstract mixin class _$CatalogHydrationDtoCopyWith<$Res> implements $CatalogHydrationDtoCopyWith<$Res> {
  factory _$CatalogHydrationDtoCopyWith(_CatalogHydrationDto value, $Res Function(_CatalogHydrationDto) _then) = __$CatalogHydrationDtoCopyWithImpl;
@override @useResult
$Res call({
 String pluginId, int projectionVersion, int completedAt
});




}
/// @nodoc
class __$CatalogHydrationDtoCopyWithImpl<$Res>
    implements _$CatalogHydrationDtoCopyWith<$Res> {
  __$CatalogHydrationDtoCopyWithImpl(this._self, this._then);

  final _CatalogHydrationDto _self;
  final $Res Function(_CatalogHydrationDto) _then;

/// Create a copy of CatalogHydrationDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pluginId = null,Object? projectionVersion = null,Object? completedAt = null,}) {
  return _then(_CatalogHydrationDto(
pluginId: null == pluginId ? _self.pluginId : pluginId // ignore: cast_nullable_to_non_nullable
as String,projectionVersion: null == projectionVersion ? _self.projectionVersion : projectionVersion // ignore: cast_nullable_to_non_nullable
as int,completedAt: null == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
