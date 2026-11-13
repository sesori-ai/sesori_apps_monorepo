// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plugin_command_invocation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PluginCommandInvocation {

 String get name; PluginCommandSource get source; String? get arguments;
/// Create a copy of PluginCommandInvocation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PluginCommandInvocationCopyWith<PluginCommandInvocation> get copyWith => _$PluginCommandInvocationCopyWithImpl<PluginCommandInvocation>(this as PluginCommandInvocation, _$identity);

  /// Serializes this PluginCommandInvocation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PluginCommandInvocation;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PluginCommandInvocation&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.arguments, _this.arguments) || other.arguments == _this.arguments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PluginCommandInvocation;
  return Object.hash(runtimeType,_this.name,_this.source,_this.arguments);
}

@override
String toString() {
  final _this = this as PluginCommandInvocation;
  return 'PluginCommandInvocation(name: ${_this.name}, source: ${_this.source}, arguments: ${_this.arguments})';
}


}

/// @nodoc
abstract mixin class $PluginCommandInvocationCopyWith<$Res>  {
  factory $PluginCommandInvocationCopyWith(PluginCommandInvocation value, $Res Function(PluginCommandInvocation) _then) = _$PluginCommandInvocationCopyWithImpl;
@useResult
$Res call({
 String name, PluginCommandSource source, String? arguments
});




}
/// @nodoc
class _$PluginCommandInvocationCopyWithImpl<$Res>
    implements $PluginCommandInvocationCopyWith<$Res> {
  _$PluginCommandInvocationCopyWithImpl(this._self, this._then);

  final PluginCommandInvocation _self;
  final $Res Function(PluginCommandInvocation) _then;

/// Create a copy of PluginCommandInvocation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? source = null,Object? arguments = freezed,}) {
  return _then(PluginCommandInvocation(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as PluginCommandSource,arguments: freezed == arguments ? _self.arguments : arguments // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}



/// @nodoc
@JsonSerializable(createFactory: false)

class _PluginCommandInvocation implements PluginCommandInvocation {
  const _PluginCommandInvocation({required this.name, required this.source, required this.arguments});
  

@override final  String name;
@override final  PluginCommandSource source;
@override final  String? arguments;

/// Create a copy of PluginCommandInvocation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PluginCommandInvocationCopyWith<_PluginCommandInvocation> get copyWith => __$PluginCommandInvocationCopyWithImpl<_PluginCommandInvocation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PluginCommandInvocationToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PluginCommandInvocation&&(identical(other.name, name) || other.name == name)&&(identical(other.source, source) || other.source == source)&&(identical(other.arguments, arguments) || other.arguments == arguments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,source,arguments);
}

@override
String toString() {
    return 'PluginCommandInvocation(name: $name, source: $source, arguments: $arguments)';
}


}

/// @nodoc
abstract mixin class _$PluginCommandInvocationCopyWith<$Res> implements $PluginCommandInvocationCopyWith<$Res> {
  factory _$PluginCommandInvocationCopyWith(_PluginCommandInvocation value, $Res Function(_PluginCommandInvocation) _then) = __$PluginCommandInvocationCopyWithImpl;
@override @useResult
$Res call({
 String name, PluginCommandSource source, String? arguments
});




}
/// @nodoc
class __$PluginCommandInvocationCopyWithImpl<$Res>
    implements _$PluginCommandInvocationCopyWith<$Res> {
  __$PluginCommandInvocationCopyWithImpl(this._self, this._then);

  final _PluginCommandInvocation _self;
  final $Res Function(_PluginCommandInvocation) _then;

/// Create a copy of PluginCommandInvocation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? source = null,Object? arguments = freezed,}) {
  return _then(_PluginCommandInvocation(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as PluginCommandSource,arguments: freezed == arguments ? _self.arguments : arguments // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
