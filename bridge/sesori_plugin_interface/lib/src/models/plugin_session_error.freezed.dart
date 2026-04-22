// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_session_error.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PluginSessionError {

 String get name; String get message;
/// Create a copy of PluginSessionError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginSessionErrorCopyWith<PluginSessionError> get copyWith => _$PluginSessionErrorCopyWithImpl<PluginSessionError>(this as PluginSessionError, _$identity);

  /// Serializes this PluginSessionError to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginSessionError&&(identical(other.name, name) || other.name == name)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,message);

@override
String toString() {
  return 'PluginSessionError(name: $name, message: $message)';
}


}

/// @nodoc
abstract mixin class $PluginSessionErrorCopyWith<$Res>  {
  factory $PluginSessionErrorCopyWith(PluginSessionError value, $Res Function(PluginSessionError) _then) = _$PluginSessionErrorCopyWithImpl;
@useResult
$Res call({
 String name, String message
});




}
/// @nodoc
class _$PluginSessionErrorCopyWithImpl<$Res>
    implements $PluginSessionErrorCopyWith<$Res> {
  _$PluginSessionErrorCopyWithImpl(this._self, this._then);

  final PluginSessionError _self;
  final $Res Function(PluginSessionError) _then;

/// Create a copy of PluginSessionError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? message = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}



/// @nodoc
@JsonSerializable()

class _PluginSessionError implements PluginSessionError {
  const _PluginSessionError({required this.name, required this.message});
  factory _PluginSessionError.fromJson(Map<String, dynamic> json) => _$PluginSessionErrorFromJson(json);

@override final  String name;
@override final  String message;

/// Create a copy of PluginSessionError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginSessionErrorCopyWith<_PluginSessionError> get copyWith => __$PluginSessionErrorCopyWithImpl<_PluginSessionError>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginSessionErrorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginSessionError&&(identical(other.name, name) || other.name == name)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,message);

@override
String toString() {
  return 'PluginSessionError(name: $name, message: $message)';
}


}

/// @nodoc
abstract mixin class _$PluginSessionErrorCopyWith<$Res> implements $PluginSessionErrorCopyWith<$Res> {
  factory _$PluginSessionErrorCopyWith(_PluginSessionError value, $Res Function(_PluginSessionError) _then) = __$PluginSessionErrorCopyWithImpl;
@override @useResult
$Res call({
 String name, String message
});




}
/// @nodoc
class __$PluginSessionErrorCopyWithImpl<$Res>
    implements _$PluginSessionErrorCopyWith<$Res> {
  __$PluginSessionErrorCopyWithImpl(this._self, this._then);

  final _PluginSessionError _self;
  final $Res Function(_PluginSessionError) _then;

/// Create a copy of PluginSessionError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? message = null,}) {
  return _then(_PluginSessionError(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
