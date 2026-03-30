// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'opencode_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OpenCodeConfig {

 String? get model;@JsonKey(name: "small_model") String? get smallModel;
/// Create a copy of OpenCodeConfig
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OpenCodeConfigCopyWith<OpenCodeConfig> get copyWith => _$OpenCodeConfigCopyWithImpl<OpenCodeConfig>(this as OpenCodeConfig, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OpenCodeConfig&&(identical(other.model, model) || other.model == model)&&(identical(other.smallModel, smallModel) || other.smallModel == smallModel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,model,smallModel);

@override
String toString() {
  return 'OpenCodeConfig(model: $model, smallModel: $smallModel)';
}


}

/// @nodoc
abstract mixin class $OpenCodeConfigCopyWith<$Res>  {
  factory $OpenCodeConfigCopyWith(OpenCodeConfig value, $Res Function(OpenCodeConfig) _then) = _$OpenCodeConfigCopyWithImpl;
@useResult
$Res call({
 String? model,@JsonKey(name: "small_model") String? smallModel
});




}
/// @nodoc
class _$OpenCodeConfigCopyWithImpl<$Res>
    implements $OpenCodeConfigCopyWith<$Res> {
  _$OpenCodeConfigCopyWithImpl(this._self, this._then);

  final OpenCodeConfig _self;
  final $Res Function(OpenCodeConfig) _then;

/// Create a copy of OpenCodeConfig
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? model = freezed,Object? smallModel = freezed,}) {
  return _then(_self.copyWith(
model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,smallModel: freezed == smallModel ? _self.smallModel : smallModel // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createToJson: false)

class _OpenCodeConfig implements OpenCodeConfig {
  const _OpenCodeConfig({this.model, @JsonKey(name: "small_model") this.smallModel});
  factory _OpenCodeConfig.fromJson(Map<String, dynamic> json) => _$OpenCodeConfigFromJson(json);

@override final  String? model;
@override@JsonKey(name: "small_model") final  String? smallModel;

/// Create a copy of OpenCodeConfig
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OpenCodeConfigCopyWith<_OpenCodeConfig> get copyWith => __$OpenCodeConfigCopyWithImpl<_OpenCodeConfig>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OpenCodeConfig&&(identical(other.model, model) || other.model == model)&&(identical(other.smallModel, smallModel) || other.smallModel == smallModel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,model,smallModel);

@override
String toString() {
  return 'OpenCodeConfig(model: $model, smallModel: $smallModel)';
}


}

/// @nodoc
abstract mixin class _$OpenCodeConfigCopyWith<$Res> implements $OpenCodeConfigCopyWith<$Res> {
  factory _$OpenCodeConfigCopyWith(_OpenCodeConfig value, $Res Function(_OpenCodeConfig) _then) = __$OpenCodeConfigCopyWithImpl;
@override @useResult
$Res call({
 String? model,@JsonKey(name: "small_model") String? smallModel
});




}
/// @nodoc
class __$OpenCodeConfigCopyWithImpl<$Res>
    implements _$OpenCodeConfigCopyWith<$Res> {
  __$OpenCodeConfigCopyWithImpl(this._self, this._then);

  final _OpenCodeConfig _self;
  final $Res Function(_OpenCodeConfig) _then;

/// Create a copy of OpenCodeConfig
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? model = freezed,Object? smallModel = freezed,}) {
  return _then(_OpenCodeConfig(
model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,smallModel: freezed == smallModel ? _self.smallModel : smallModel // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
